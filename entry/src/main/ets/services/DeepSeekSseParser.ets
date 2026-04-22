import { ResponseMetadata, UsageInfo, createEmptyUsage } from '../models/ApiModels';

export interface StreamDelta {
  content: string;
  reasoningContent: string;
  metadata: ResponseMetadata | null;
  usage: UsageInfo | null;
  finishReason: string;
  done: boolean;
}

export function createEmptyDelta(): StreamDelta {
  return {
    content: '',
    reasoningContent: '',
    metadata: null,
    usage: null,
    finishReason: '',
    done: false
  };
}

export function parseSseChunk(chunk: string): StreamDelta[] {
  const deltas: StreamDelta[] = [];
  const events: string[] = chunk.replace(/\r\n/g, '\n').split('\n\n');

  for (let i = 0; i < events.length; i++) {
    const eventText: string = events[i].trim();
    if (eventText.length === 0 || eventText.startsWith(':')) {
      continue;
    }

    const lines: string[] = eventText.split('\n');
    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line: string = lines[lineIndex].trim();
      if (!line.startsWith('data:')) {
        continue;
      }

      const payload: string = line.substring(5).trim();
      if (payload === '[DONE]') {
        const doneDelta: StreamDelta = createEmptyDelta();
        doneDelta.done = true;
        deltas.push(doneDelta);
        continue;
      }

      const parsed: StreamDelta | null = parseDataPayload(payload);
      if (parsed !== null) {
        deltas.push(parsed);
      }
    }
  }

  return deltas;
}

export function mapDeepSeekError(statusCode: number, fallback: string): string {
  if (statusCode === 401) {
    return 'API Key 无效，请检查密钥。';
  }
  if (statusCode === 402) {
    return '余额不足或账户不可用。';
  }
  if (statusCode === 429) {
    return '请求过于频繁，请稍后重试。';
  }
  if (statusCode >= 500 && statusCode <= 599) {
    return 'DeepSeek 服务异常，请稍后重试。';
  }
  if (fallback.length > 0) {
    return fallback;
  }
  return '请求失败，请稍后重试。';
}

export function stripHistoricalReasoning(content: string, reasoningContent: string, keepReasoning: boolean): string {
  if (keepReasoning || reasoningContent.length === 0) {
    return reasoningContent;
  }
  return '';
}

function parseDataPayload(payload: string): StreamDelta | null {
  try {
    const root = JSON.parse(payload) as Record<string, Object>;
    const delta: StreamDelta = createEmptyDelta();
    const choices = root['choices'] as Array<Record<string, Object>>;
    if (choices !== undefined && choices.length > 0) {
      const firstChoice = choices[0];
      const choiceDelta = firstChoice['delta'] as Record<string, Object>;
      if (choiceDelta !== undefined) {
        delta.content = stringField(choiceDelta, 'content');
        delta.reasoningContent = stringField(choiceDelta, 'reasoning_content');
      }
      delta.finishReason = stringField(firstChoice, 'finish_reason');
    }

    delta.metadata = {
      responseId: stringField(root, 'id'),
      model: stringField(root, 'model'),
      created: numberField(root, 'created'),
      systemFingerprint: stringField(root, 'system_fingerprint'),
      finishReason: delta.finishReason
    };

    const usage = root['usage'] as Record<string, Object>;
    if (usage !== undefined) {
      delta.usage = parseUsage(usage);
    }

    return delta;
  } catch (err) {
    return null;
  }
}

function parseUsage(usage: Record<string, Object>): UsageInfo {
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

function stringField(source: Record<string, Object>, key: string): string {
  const value = source[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function numberField(source: Record<string, Object>, key: string): number {
  const value = source[key];
  if (typeof value === 'number') {
    return value;
  }
  return 0;
}
