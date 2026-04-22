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
