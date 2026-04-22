import { common } from '@kit.AbilityKit';
import { ApiMessage, ModelMode, ResponseMetadata, UsageInfo } from '../models/ApiModels';
import {
  ChatMessage,
  Conversation,
  MessageRole,
  SendStatus,
  createConversation,
  createConversationTitle,
  createMessage
} from '../models/ChatModels';
import { AppSettings, createDefaultSettings } from '../models/SettingsModels';
import { DeepSeekService } from '../services/DeepSeekService';
import { PreferencesService } from '../services/PreferencesService';

@Observed
export class ChatViewModel {
  conversations: Conversation[] = [];
  currentConversationId: string = '';
  messages: ChatMessage[] = [];
  inputText: string = '';
  isLoading: boolean = false;
  errorMessage: string = '';
  modelMode: ModelMode = ModelMode.CHAT;
  fontSize: number = 15;
  webSearchEnabled: boolean = false;
  backgroundEnabled: boolean = false;
  backgroundImageUri: string = '';
  backgroundOpacity: number = 0.3;
  backgroundBlurRadius: number = 20;

  private initialized: boolean = false;
  private settings: AppSettings = createDefaultSettings();
  private preferencesService: PreferencesService = new PreferencesService();
  private deepSeekService: DeepSeekService = new DeepSeekService();

  init(context: common.Context): void {
    if (this.initialized) {
      return;
    }
    try {
      this.preferencesService.init(context);
      this.settings = this.preferencesService.loadSettings();
    } catch (err) {
      this.settings = createDefaultSettings();
    }
    this.applySettings(this.settings);
    this.createNewConversation();
    this.initialized = true;
  }

  setApiKey(key: string): void {
    this.deepSeekService.setApiKey(key);
  }

  createNewConversation(): void {
    const conversation: Conversation = createConversation('New chat');
    this.conversations = [conversation].concat(this.conversations);
    this.currentConversationId = conversation.id;
    this.messages = [];
    this.errorMessage = '';
  }

  switchConversation(id: string): void {
    const conversation: Conversation | null = this.findConversation(id);
    if (conversation === null) {
      return;
    }
    this.currentConversationId = conversation.id;
    this.messages = conversation.messages;
    this.errorMessage = '';
  }

  deleteConversation(id: string): void {
    const nextConversations: Conversation[] = [];
    for (let i = 0; i < this.conversations.length; i++) {
      if (this.conversations[i].id !== id) {
        nextConversations.push(this.conversations[i]);
      }
    }
    this.conversations = nextConversations;
    if (this.currentConversationId !== id) {
      return;
    }
    if (this.conversations.length > 0) {
      this.currentConversationId = this.conversations[0].id;
      this.messages = this.conversations[0].messages;
    } else {
      this.createNewConversation();
    }
  }

  async sendMessage(): Promise<void> {
    const content: string = this.inputText.trim();
    if (content.length === 0 || this.isLoading) {
      return;
    }

    const conversationId: string = this.ensureConversation();
    const userMessage: ChatMessage = createMessage(conversationId, MessageRole.USER, content);
    userMessage.status = SendStatus.SUCCESS;

    const assistantMessage: ChatMessage = createMessage(conversationId, MessageRole.ASSISTANT, '');
    assistantMessage.status = SendStatus.SENDING;

    this.messages = this.messages.concat([userMessage, assistantMessage]);
    this.inputText = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.updateCurrentConversation(content);

    await this.deepSeekService.sendStreamChat(this.toApiMessages(this.messages), this.modelMode, {
      onContent: (chunk: string): void => {
        this.appendAssistantContent(assistantMessage.id, chunk);
      },
      onReasoning: (chunk: string): void => {
        this.appendAssistantReasoning(assistantMessage.id, chunk);
      },
      onMetadata: (metadata: ResponseMetadata): void => {
        this.updateAssistantMetadata(assistantMessage.id, metadata);
      },
      onUsage: (usage: UsageInfo): void => {
        this.updateAssistantUsage(assistantMessage.id, usage);
      },
      onError: (message: string): void => {
        this.failAssistantMessage(assistantMessage.id, message);
      },
      onComplete: (metadata: ResponseMetadata | null, usage: UsageInfo | null): void => {
        this.completeAssistantMessage(assistantMessage.id, metadata, usage);
      }
    });
  }

  stopGenerating(): void {
    this.deepSeekService.cancelRequest();
    this.isLoading = false;
    const updated: ChatMessage[] = this.messages.slice();
    for (let i = updated.length - 1; i >= 0; i--) {
      if (updated[i].role === MessageRole.ASSISTANT && updated[i].status === SendStatus.SENDING) {
        updated[i].status = updated[i].content.length > 0 ? SendStatus.CANCELED : SendStatus.FAILED;
        updated[i].errorMessage = updated[i].content.length > 0 ? '' : '已停止生成。';
        updated[i].updatedAt = Date.now();
        break;
      }
    }
    this.messages = updated;
    this.syncCurrentMessages();
  }

  async retryLastMessage(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const updated: ChatMessage[] = this.messages.slice();
    if (updated.length < 2) {
      return;
    }
    const last: ChatMessage = updated[updated.length - 1];
    if (last.role === MessageRole.ASSISTANT) {
      updated.pop();
    }
    const userMessage: ChatMessage = updated[updated.length - 1];
    if (userMessage.role !== MessageRole.USER) {
      return;
    }
    updated.pop();
    this.messages = updated;
    this.inputText = userMessage.content;
    this.syncCurrentMessages();
    await this.sendMessage();
  }

  deleteMessage(id: string): void {
    const nextMessages: ChatMessage[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      if (this.messages[i].id !== id) {
        nextMessages.push(this.messages[i]);
      }
    }
    this.messages = nextMessages;
    this.syncCurrentMessages();
  }

  renameConversation(id: string, title: string): void {
    const cleanTitle: string = title.trim();
    if (cleanTitle.length === 0) {
      return;
    }
    const conversations: Conversation[] = this.conversations.slice();
    for (let i = 0; i < conversations.length; i++) {
      if (conversations[i].id === id) {
        conversations[i].title = createConversationTitle(cleanTitle);
        conversations[i].updatedAt = Date.now();
        break;
      }
    }
    this.conversations = conversations;
  }

  toggleWebSearch(): void {
    this.webSearchEnabled = !this.webSearchEnabled;
  }

  getCurrentTitle(): string {
    const conversation: Conversation | null = this.findConversation(this.currentConversationId);
    if (conversation === null) {
      return 'New chat';
    }
    return conversation.title;
  }

  private applySettings(settings: AppSettings): void {
    this.modelMode = settings.modelMode;
    this.fontSize = settings.fontSize;
    this.webSearchEnabled = settings.webSearchDefaultEnabled;
    this.backgroundEnabled = settings.backgroundEnabled;
    this.backgroundImageUri = settings.backgroundImageUri;
    this.backgroundOpacity = settings.backgroundOpacity;
    this.backgroundBlurRadius = settings.backgroundBlurRadius;
  }

  private ensureConversation(): string {
    if (this.currentConversationId.length > 0 && this.findConversation(this.currentConversationId) !== null) {
      return this.currentConversationId;
    }
    const conversation: Conversation = createConversation('New chat');
    this.conversations = [conversation].concat(this.conversations);
    this.currentConversationId = conversation.id;
    this.messages = [];
    return conversation.id;
  }

  private findConversation(id: string): Conversation | null {
    for (let i = 0; i < this.conversations.length; i++) {
      if (this.conversations[i].id === id) {
        return this.conversations[i];
      }
    }
    return null;
  }

  private updateCurrentConversation(firstMessage: string): void {
    const conversations: Conversation[] = this.conversations.slice();
    for (let i = 0; i < conversations.length; i++) {
      if (conversations[i].id === this.currentConversationId) {
        if (conversations[i].messages.length === 0) {
          conversations[i].title = createConversationTitle(firstMessage);
        }
        conversations[i].messages = this.messages;
        conversations[i].updatedAt = Date.now();
        break;
      }
    }
    this.conversations = conversations;
  }

  private syncCurrentMessages(): void {
    const conversations: Conversation[] = this.conversations.slice();
    for (let i = 0; i < conversations.length; i++) {
      if (conversations[i].id === this.currentConversationId) {
        conversations[i].messages = this.messages;
        conversations[i].updatedAt = Date.now();
        break;
      }
    }
    this.conversations = conversations;
  }

  private toApiMessages(messages: ChatMessage[]): ApiMessage[] {
    const apiMessages: ApiMessage[] = [];
    for (let i = 0; i < messages.length; i++) {
      const message: ChatMessage = messages[i];
      if (message.status === SendStatus.FAILED || message.status === SendStatus.CANCELED || message.status === SendStatus.SENDING) {
        continue;
      }
      apiMessages.push({
        role: message.role,
        content: message.content,
        reasoningContent: message.reasoningContent
      });
    }
    return apiMessages;
  }

  private appendAssistantContent(id: string, chunk: string): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.content += chunk;
    });
  }

  private appendAssistantReasoning(id: string, chunk: string): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.reasoningContent += chunk;
    });
  }

  private updateAssistantMetadata(id: string, metadata: ResponseMetadata): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.responseId = metadata.responseId;
      message.model = metadata.model;
      message.finishReason = metadata.finishReason;
      message.systemFingerprint = metadata.systemFingerprint;
    });
  }

  private updateAssistantUsage(id: string, usage: UsageInfo): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.promptTokens = usage.promptTokens;
      message.completionTokens = usage.completionTokens;
      message.totalTokens = usage.totalTokens;
      message.reasoningTokens = usage.reasoningTokens;
      message.cacheHitTokens = usage.cacheHitTokens;
      message.cacheMissTokens = usage.cacheMissTokens;
    });
  }

  private failAssistantMessage(id: string, errorMessage: string): void {
    this.errorMessage = errorMessage;
    this.isLoading = false;
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.status = SendStatus.FAILED;
      message.errorMessage = errorMessage;
    });
  }

  private completeAssistantMessage(id: string, metadata: ResponseMetadata | null, usage: UsageInfo | null): void {
    this.isLoading = false;
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      if (metadata !== null) {
        message.responseId = metadata.responseId;
        message.model = metadata.model;
        message.finishReason = metadata.finishReason;
        message.systemFingerprint = metadata.systemFingerprint;
      }
      if (usage !== null) {
        message.promptTokens = usage.promptTokens;
        message.completionTokens = usage.completionTokens;
        message.totalTokens = usage.totalTokens;
        message.reasoningTokens = usage.reasoningTokens;
        message.cacheHitTokens = usage.cacheHitTokens;
        message.cacheMissTokens = usage.cacheMissTokens;
      }
      if (message.status === SendStatus.SENDING) {
        message.status = SendStatus.SUCCESS;
      }
    });
  }

  private updateAssistantMessage(id: string, updater: (message: ChatMessage) => void): void {
    const updated: ChatMessage[] = this.messages.slice();
    for (let i = 0; i < updated.length; i++) {
      if (updated[i].id === id) {
        updater(updated[i]);
        updated[i].updatedAt = Date.now();
        break;
      }
    }
    this.messages = updated;
    this.syncCurrentMessages();
  }
}
