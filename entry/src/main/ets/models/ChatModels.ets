import { SearchResult, ToolCallRecord } from './SearchModels';

export enum MessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system',
  TOOL = 'tool'
}

export enum SendStatus {
  IDLE = 'idle',
  SENDING = 'sending',
  SUCCESS = 'success',
  FAILED = 'failed',
  CANCELED = 'canceled'
}

export class ChatMessage {
  id: string = '';
  conversationId: string = '';
  role: MessageRole = MessageRole.USER;
  content: string = '';
  reasoningContent: string = '';
  status: SendStatus = SendStatus.IDLE;
  errorMessage: string = '';
  responseId: string = '';
  model: string = '';
  finishReason: string = '';
  systemFingerprint: string = '';
  promptTokens: number = 0;
  completionTokens: number = 0;
  totalTokens: number = 0;
  reasoningTokens: number = 0;
  cacheHitTokens: number = 0;
  cacheMissTokens: number = 0;
  branchParentId: string = '';
  branchIndex: number = 0;
  branchActive: boolean = true;
  pathParentId: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  searchSources: SearchResult[] = [];
  toolCalls: ToolCallRecord[] = [];
}

export class Conversation {
  id: string = '';
  title: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  messages: ChatMessage[] = [];
}

export function createConversation(title: string): Conversation {
  const now: number = Date.now();
  const conversation: Conversation = new Conversation();
  conversation.id = createLocalId('conv');
  conversation.title = title.length > 0 ? title : 'New chat';
  conversation.createdAt = now;
  conversation.updatedAt = now;
  conversation.messages = [];
  return conversation;
}

export function createMessage(conversationId: string, role: MessageRole, content: string): ChatMessage {
  const now: number = Date.now();
  const message: ChatMessage = new ChatMessage();
  message.id = createLocalId('msg');
  message.conversationId = conversationId;
  message.role = role;
  message.content = content;
  message.status = SendStatus.IDLE;
  message.createdAt = now;
  message.updatedAt = now;
  return message;
}

export function createConversationTitle(content: string): string {
  const title: string = content.trim().replace(/\s+/g, ' ');
  if (title.length === 0) {
    return 'New chat';
  }
  if (title.length > 28) {
    return title.substring(0, 28);
  }
  return title;
}

function createLocalId(prefix: string): string {
  const randomPart: number = Math.floor(Math.random() * 1000000);
  return `${prefix}_${Date.now()}_${randomPart}`;
}
