import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import {
  ApiMessage,
  ApiRequestMessage,
  ApiToolCall,
  ApiToolCallFunction,
  ApiToolDefinition,
  BalanceInfo,
  BalanceResponse,
  ChatCompletionResponse,
  ChatCompletionRequest,
  ModelInfo,
  ModelListResponse,
  ModelMode,
  ResponseMetadata,
  StreamCallback,
  UsageInfo,
  createEmptyUsage,
  getDeepSeekModelId
} from '../models/ApiModels';
import {
  CHAT_DEFAULT_MAX_TOKENS,
  DEEPSEEK_BALANCE_ENDPOINT,
  DEEPSEEK_BASE_URL,
  DEEPSEEK_CHAT_ENDPOINT,
  DEEPSEEK_MODELS_ENDPOINT,
  DEEPSEEK_REQUEST_TIMEOUT,
  REASONER_DEFAULT_MAX_TOKENS
} from '../shared/Constants';
import { StreamDelta, mapDeepSeekError, parseSseChunk } from './DeepSeekSseParser';

export class DeepSeekService {
  private apiKey: string = '';
  private currentRequest: http.HttpRequest | null = null;
  private streamBuffer: string = '';
  private latestMetadata: ResponseMetadata | null = null;
  private latestUsage: UsageInfo | null = null;
  private streamCompleted: boolean = false;

  setApiKey(key: string): void {
    this.apiKey = key.trim();
  }

  cancelRequest(): void {
    if (this.currentRequest !== null) {
      this.destroyRequest(this.currentRequest);
    }
  }

  async sendStreamChat(messages: ApiMessage[], mode: ModelMode, callback: StreamCallback): Promise<void> {
    if (this.apiKey.length === 0) {
      callback.onError('请先配置 DeepSeek API Key。');
      return;
    }

    this.cancelRequest();
    this.streamBuffer = '';
    this.latestMetadata = null;
    this.latestUsage = null;
    this.streamCompleted = false;

    const requestBody: ChatCompletionRequest = this.buildRequestBody(messages, mode);
    const request = http.createHttp();
    this.currentRequest = request;
    const decoder = util.TextDecoder.create('utf-8');

    return new Promise<void>((resolve) => {
      request.on('dataReceive', (data: ArrayBuffer) => {
        const chunk: string = decoder.decodeToString(new Uint8Array(data));
        this.handleStreamText(chunk, callback);
      });

      request.on('dataEnd', () => {
        if (this.streamBuffer.length > 0) {
          this.handleStreamText('\n\n', callback);
        }
        if (!this.streamCompleted) {
          callback.onComplete(this.latestMetadata, this.latestUsage);
          this.streamCompleted = true;
        }
        this.destroyRequest(request);
        resolve();
      });

      request.requestInStream(
        `${DEEPSEEK_BASE_URL}${DEEPSEEK_CHAT_ENDPOINT}`,
        {
          method: http.RequestMethod.POST,
          header: this.buildJsonHeaders(),
          extraData: JSON.stringify(requestBody),
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          priority: 1,
          readTimeout: DEEPSEEK_REQUEST_TIMEOUT,
          connectTimeout: DEEPSEEK_REQUEST_TIMEOUT,
          usingProtocol: http.HttpProtocol.HTTP1_1
        }
      ).then((responseCode: number) => {
          if (responseCode >= 400) {
            callback.onError(mapDeepSeekError(responseCode, 'DeepSeek 请求失败。'));
            this.destroyRequest(request);
            resolve();
          }
      }).catch((_err: Error) => {
        callback.onError('网络请求失败，请稍后重试。');
        this.destroyRequest(request);
        resolve();
      });
    });
  }

  async fetchModels(): Promise<ModelListResponse | null> {
    if (this.apiKey.length === 0) {
      return null;
    }
    const text: string = await this.requestText(`${DEEPSEEK_BASE_URL}${DEEPSEEK_MODELS_ENDPOINT}`, http.RequestMethod.GET, '');
    if (text.length === 0) {
      return null;
    }
    return parseModelListResponse(text);
  }

  async fetchBalance(): Promise<BalanceResponse | null> {
    if (this.apiKey.length === 0) {
      return null;
    }
    const text: string = await this.requestText(`${DEEPSEEK_BASE_URL}${DEEPSEEK_BALANCE_ENDPOINT}`, http.RequestMethod.GET, '');
    if (text.length === 0) {
      return null;
    }
    return parseBalanceResponse(text);
  }

  async sendToolRound(messages: ApiMessage[], mode: ModelMode, tools: ApiToolDefinition[]): Promise<ChatCompletionResponse | null> {
    if (this.apiKey.length === 0) {
      return null;
    }
    const requestBody: ChatCompletionRequest = this.buildToolRequestBody(messages, mode, tools);
    const text: string = await this.requestText(
      `${DEEPSEEK_BASE_URL}${DEEPSEEK_CHAT_ENDPOINT}`,
      http.RequestMethod.POST,
      JSON.stringify(requestBody)
    );
    if (text.length === 0) {
      return null;
    }
    return parseChatCompletionResponse(text);
  }

  buildRequestBody(messages: ApiMessage[], mode: ModelMode): ChatCompletionRequest {
    const isReasoner: boolean = mode === ModelMode.REASONER;
    const request: ChatCompletionRequest = {
      model: getDeepSeekModelId(mode),
      messages: this.toRequestMessages(messages, !isReasoner),
      stream: true,
      stream_options: { include_usage: true },
      max_tokens: isReasoner ? REASONER_DEFAULT_MAX_TOKENS : CHAT_DEFAULT_MAX_TOKENS
    };
    if (!isReasoner) {
      request.temperature = 1.0;
    }
    return request;
  }

  buildToolRequestBody(messages: ApiMessage[], mode: ModelMode, tools: ApiToolDefinition[]): ChatCompletionRequest {
    const isReasoner: boolean = mode === ModelMode.REASONER;
    const request: ChatCompletionRequest = {
      model: getDeepSeekModelId(mode),
      messages: this.toRequestMessages(messages, true),
      stream: false,
      max_tokens: isReasoner ? REASONER_DEFAULT_MAX_TOKENS : CHAT_DEFAULT_MAX_TOKENS,
      tools: tools,
      tool_choice: 'auto'
    };
    if (!isReasoner) {
      request.temperature = 1.0;
    }
    return request;
  }

  private toRequestMessages(messages: ApiMessage[], keepReasoning: boolean): ApiRequestMessage[] {
    const items: ApiRequestMessage[] = [];
    for (let i = 0; i < messages.length; i++) {
      const message: ApiMessage = messages[i];
      const item: ApiRequestMessage = {
        role: message.role,
        content: message.content
      };
      if (keepReasoning && message.reasoningContent !== undefined && message.reasoningContent.length > 0) {
        item.reasoning_content = message.reasoningContent;
      }
      if (message.toolCallId !== undefined && message.toolCallId.length > 0) {
        item.tool_call_id = message.toolCallId;
      }
      if (message.toolCallsJson !== undefined && message.toolCallsJson.length > 0) {
        const toolCalls: Object[] = this.parseToolCallsJson(message.toolCallsJson);
        if (toolCalls.length > 0) {
          item.tool_calls = toolCalls;
        }
      }
      items.push(item);
    }
    return items;
  }

  private parseToolCallsJson(text: string): Object[] {
    try {
      const parsed = JSON.parse(text) as Object[];
      if (Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_err) {
    }
    return [];
  }

  private handleStreamText(text: string, callback: StreamCallback): void {
    this.streamBuffer += text;
    const normalized: string = this.streamBuffer.replace(/\r\n/g, '\n');
    const events: string[] = normalized.split('\n\n');
    this.streamBuffer = events.pop() ?? '';
    const completeText: string = events.join('\n\n');
    if (completeText.length === 0) {
      return;
    }

    const deltas: StreamDelta[] = parseSseChunk(`${completeText}\n\n`);
    for (let i = 0; i < deltas.length; i++) {
      const delta: StreamDelta = deltas[i];
      if (delta.content.length > 0) {
        callback.onContent(delta.content);
      }
      if (delta.reasoningContent.length > 0) {
        callback.onReasoning(delta.reasoningContent);
      }
      if (delta.metadata !== null) {
        this.latestMetadata = delta.metadata;
        callback.onMetadata(delta.metadata);
      }
      if (delta.usage !== null) {
        this.latestUsage = delta.usage;
        callback.onUsage(delta.usage);
      }
      if (delta.done) {
        if (!this.streamCompleted) {
          callback.onComplete(this.latestMetadata, this.latestUsage);
          this.streamCompleted = true;
        }
      }
    }
  }

  private requestText(url: string, method: http.RequestMethod, body: string): Promise<string> {
    const request = http.createHttp();
    return new Promise<string>((resolve) => {
      request.request(
        url,
        {
          method: method,
          header: this.buildJsonHeaders(),
          extraData: body,
          readTimeout: DEEPSEEK_REQUEST_TIMEOUT,
          connectTimeout: DEEPSEEK_REQUEST_TIMEOUT
        },
        (err: BusinessError, data: http.HttpResponse) => {
          if (err || data.responseCode >= 400) {
            request.destroy();
            resolve('');
            return;
          }
          request.destroy();
          if (typeof data.result === 'string') {
            resolve(data.result);
            return;
          }
          resolve(JSON.stringify(data.result));
        }
      );
    });
  }

  private buildJsonHeaders(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`
    };
  }

  private cleanupRequest(request: http.HttpRequest): void {
    this.destroyRequest(request);
  }

  private destroyRequest(request: http.HttpRequest): void {
    if (this.currentRequest !== request) {
      return;
    }
    request.off('dataReceive');
    request.off('dataSendProgress');
    request.off('dataReceiveProgress');
    request.off('dataEnd');
    request.destroy();
    this.currentRequest = null;
  }
}

export function parseModelListResponse(text: string): ModelListResponse | null {
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const data = root['data'] as Array<Record<string, Object>>;
    const models: ModelInfo[] = [];
    if (data !== undefined) {
      for (let i = 0; i < data.length; i++) {
        models.push({
          id: stringField(data[i], 'id'),
          object: stringField(data[i], 'object'),
          ownedBy: stringField(data[i], 'owned_by')
        });
      }
    }
    return {
      object: stringField(root, 'object'),
      data: models
    };
  } catch (err) {
    return null;
  }
}

export function parseBalanceResponse(text: string): BalanceResponse | null {
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const data = root['balance_infos'] as Array<Record<string, Object>>;
    const balanceInfos: BalanceInfo[] = [];
    if (data !== undefined) {
      for (let i = 0; i < data.length; i++) {
        balanceInfos.push({
          currency: stringField(data[i], 'currency'),
          totalBalance: stringField(data[i], 'total_balance'),
          grantedBalance: stringField(data[i], 'granted_balance'),
          toppedUpBalance: stringField(data[i], 'topped_up_balance')
        });
      }
    }
    return {
      isAvailable: booleanField(root, 'is_available'),
      balanceInfos: balanceInfos
    };
  } catch (err) {
    return null;
  }
}

function stringField(source: Record<string, Object>, key: string): string {
  const value = source[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function booleanField(source: Record<string, Object>, key: string): boolean {
  const value = source[key];
  if (typeof value === 'boolean') {
    return value;
  }
  return false;
}

export function parseChatCompletionResponse(text: string): ChatCompletionResponse | null {
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const choices = root['choices'] as Array<Record<string, Object>>;
    const usage = root['usage'] as Record<string, Object>;
    const response: ChatCompletionResponse = {
      content: '',
      reasoningContent: '',
      metadata: {
        responseId: stringField(root, 'id'),
        model: stringField(root, 'model'),
        created: numberField(root, 'created'),
        systemFingerprint: stringField(root, 'system_fingerprint'),
        finishReason: ''
      },
      usage: usage !== undefined ? parseCompletionUsage(usage) : createEmptyUsage(),
      toolCalls: []
    };
    if (choices !== undefined && choices.length > 0) {
      const firstChoice = choices[0];
      response.metadata.finishReason = stringField(firstChoice, 'finish_reason');
      const message = firstChoice['message'] as Record<string, Object>;
      if (message !== undefined) {
        response.content = stringField(message, 'content');
        response.reasoningContent = stringField(message, 'reasoning_content');
        response.toolCalls = parseToolCalls(message['tool_calls'] as Array<Record<string, Object>>);
      }
    }
    return response;
  } catch (_err) {
    return null;
  }
}

function parseToolCalls(items: Array<Record<string, Object>>): ApiToolCall[] {
  const toolCalls: ApiToolCall[] = [];
  if (items === undefined) {
    return toolCalls;
  }
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const fn = item['function'] as Record<string, Object>;
    const callFunction: ApiToolCallFunction = {
      name: fn !== undefined ? stringField(fn, 'name') : '',
      arguments: fn !== undefined ? stringField(fn, 'arguments') : ''
    };
    toolCalls.push({
      id: stringField(item, 'id'),
      type: stringField(item, 'type'),
      function: callFunction
    });
  }
  return toolCalls;
}

function parseCompletionUsage(usage: Record<string, Object>): UsageInfo {
  const completionDetails = usage['completion_tokens_details'] as Record<string, Object>;
  const promptDetails = usage['prompt_tokens_details'] as Record<string, Object>;
  const info: UsageInfo = createEmptyUsage();
  info.promptTokens = numberField(usage, 'prompt_tokens');
  info.completionTokens = numberField(usage, 'completion_tokens');
  info.totalTokens = numberField(usage, 'total_tokens');
  if (completionDetails !== undefined) {
    info.reasoningTokens = numberField(completionDetails, 'reasoning_tokens');
  }
  if (promptDetails !== undefined) {
    info.cacheHitTokens = numberField(promptDetails, 'cached_tokens');
    info.cacheMissTokens = Math.max(info.promptTokens - info.cacheHitTokens, 0);
  }
  return info;
}

function numberField(source: Record<string, Object>, key: string): number {
  const value = source[key];
  if (typeof value === 'number') {
    return value;
  }
  return 0;
}
