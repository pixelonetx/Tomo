export enum ModelMode {
  CHAT = 'chat',
  REASONER = 'reasoner'
}

export interface ApiMessage {
  role: string;
  content: string;
  reasoningContent?: string;
  toolCallId?: string;
  toolCallsJson?: string;
}

export interface ApiRequestMessage {
  role: string;
  content: string;
  reasoning_content?: string;
  tool_call_id?: string;
  tool_calls?: Object[];
}

export interface ChatCompletionRequest {
  model: string;
  messages: ApiRequestMessage[];
  stream: boolean;
  stream_options?: StreamOptions;
  temperature?: number;
  max_tokens: number;
  tools?: ApiToolDefinition[];
  tool_choice?: string;
}

export interface StreamOptions {
  include_usage: boolean;
}

export interface UsageInfo {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  reasoningTokens: number;
  cacheHitTokens: number;
  cacheMissTokens: number;
}

export interface ResponseMetadata {
  responseId: string;
  model: string;
  created: number;
  systemFingerprint: string;
  finishReason: string;
}

export interface ApiToolDefinition {
  type: string;
  function: ApiToolFunction;
}

export interface ApiToolFunction {
  name: string;
  description: string;
  parameters: ApiToolParameters;
}

export interface ApiToolParameters {
  type: string;
  properties: ApiToolParameterProperties;
  required: string[];
  additionalProperties: boolean;
}

export interface ApiToolParameterProperties {
  query: ApiToolStringParameter;
  freshness: ApiToolStringParameter;
}

export interface ApiToolStringParameter {
  type: string;
  description: string;
  enum?: string[];
}

export interface ApiToolCall {
  id: string;
  type: string;
  function: ApiToolCallFunction;
}

export interface ApiToolCallDelta {
  index: number;
  id: string;
  type: string;
  function: ApiToolCallFunction;
}

export interface ApiToolCallFunction {
  name: string;
  arguments: string;
}

export interface ModelInfo {
  id: string;
  object: string;
  ownedBy: string;
}

export interface ModelListResponse {
  object: string;
  data: ModelInfo[];
}

export interface BalanceInfo {
  currency: string;
  totalBalance: string;
  grantedBalance: string;
  toppedUpBalance: string;
}

export interface BalanceResponse {
  isAvailable: boolean;
  balanceInfos: BalanceInfo[];
}

export interface ChatCompletionResponse {
  content: string;
  reasoningContent: string;
  metadata: ResponseMetadata;
  usage: UsageInfo;
  toolCalls: ApiToolCall[];
}

export interface StreamCallback {
  onContent: (chunk: string) => void;
  onReasoning: (chunk: string) => void;
  onMetadata: (metadata: ResponseMetadata) => void;
  onUsage: (usage: UsageInfo) => void;
  onError: (message: string) => void;
  onComplete: (metadata: ResponseMetadata | null, usage: UsageInfo | null) => void;
}

export function getDeepSeekModelId(mode: ModelMode): string {
  if (mode === ModelMode.REASONER) {
    return 'deepseek-reasoner';
  }
  return 'deepseek-chat';
}

export function createEmptyUsage(): UsageInfo {
  return {
    promptTokens: 0,
    completionTokens: 0,
    totalTokens: 0,
    reasoningTokens: 0,
    cacheHitTokens: 0,
    cacheMissTokens: 0
  };
}
