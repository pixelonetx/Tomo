import { common } from '@kit.AbilityKit';
import { ApiMessage, ApiToolCall, BalanceInfo, BalanceResponse, ChatCompletionResponse, ModelInfo, ModelListResponse, ModelMode, ResponseMetadata, UsageInfo } from '../models/ApiModels';
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
import { SearchOptions, SearchResult, ToolCallRecord, mergeSearchSources } from '../models/SearchModels';
import { ConversationService } from '../services/ConversationService';
import { DeepSeekService } from '../services/DeepSeekService';
import { PreferencesService } from '../services/PreferencesService';
import {
  ParsedWebSearchArguments,
  SearchService,
  TavilySearchProvider,
  WEB_SEARCH_TOOL_NAME,
  createFailedToolResultJson,
  createSearchToolResultJson,
  createToolCallRecord,
  createWebSearchToolDefinition,
  parseWebSearchArguments
} from '../services/SearchToolService';
import {
  CONTEXT_EXTENDED_CHAR_BUDGET,
  CONTEXT_STANDARD_CHAR_BUDGET,
  MAX_MESSAGE_CHARS,
  MAX_RECENT_MESSAGES,
  MAX_SEARCH_RESULTS_PER_CALL,
  MAX_TOOL_CALLS_PER_ROUND,
  MAX_TOOL_ROUNDS
} from '../shared/Constants';

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
  apiKeyConfigured: boolean = false;
  apiKeyDraft: string = '';
  searchApiKeyConfigured: boolean = false;
  searchApiKeyDraft: string = '';
  settingsMessage: string = '';
  balanceMessage: string = '';

  private initialized: boolean = false;
  private settings: AppSettings = createDefaultSettings();
  private preferencesService: PreferencesService = new PreferencesService();
  private deepSeekService: DeepSeekService = new DeepSeekService();
  private tavilySearchProvider: TavilySearchProvider = new TavilySearchProvider();
  private searchService: SearchService = new SearchService();
  private conversationService: ConversationService = new ConversationService();
  private lastAssistantPersistAt: number = 0;

  init(context: common.Context): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.initialize(context);
  }

  private async initialize(context: common.Context): Promise<void> {
    try {
      this.preferencesService.init(context);
      this.settings = this.preferencesService.loadSettings();
    } catch (err) {
      this.settings = createDefaultSettings();
    }
    this.applySettings(this.settings);
    await this.restoreApiKey();
    await this.restoreSearchApiKey();
    this.searchService.setProvider(this.tavilySearchProvider);
    try {
      await this.conversationService.init(context);
      this.conversations = await this.conversationService.loadConversations();
    } catch (err) {
      this.conversations = [];
      this.errorMessage = '会话数据库初始化失败，本次启动仅使用内存会话。';
    }
    if (this.conversations.length > 0) {
      this.currentConversationId = this.conversations[0].id;
      this.messages = this.conversations[0].messages;
      return;
    }
    await this.createNewConversation();
  }

  setApiKey(key: string): void {
    this.deepSeekService.setApiKey(key);
    this.apiKeyDraft = key;
    this.apiKeyConfigured = key.trim().length > 0;
  }

  async saveApiKey(key: string): Promise<void> {
    const cleanKey: string = key.trim();
    this.setApiKey(cleanKey);
    try {
      await this.preferencesService.saveApiKey(cleanKey);
      this.settings.apiKeyConfigured = cleanKey.length > 0;
      this.settingsMessage = cleanKey.length > 0 ? 'API Key saved.' : 'API Key cleared.';
    } catch (err) {
      this.settingsMessage = 'API Key 保存失败，请稍后重试。';
    }
  }

  async clearApiKey(): Promise<void> {
    this.setApiKey('');
    try {
      await this.preferencesService.clearApiKey();
      this.settings.apiKeyConfigured = false;
      this.settingsMessage = 'API Key cleared.';
    } catch (err) {
      this.settingsMessage = 'API Key 清除失败，请稍后重试。';
    }
  }

  setSearchApiKey(key: string): void {
    this.tavilySearchProvider.setApiKey(key);
    this.searchApiKeyDraft = key;
    this.searchApiKeyConfigured = key.trim().length > 0;
  }

  async saveSearchApiKey(key: string): Promise<void> {
    const cleanKey: string = key.trim();
    this.setSearchApiKey(cleanKey);
    try {
      await this.preferencesService.saveSearchApiKey(cleanKey);
      this.settings.searchApiKeyConfigured = cleanKey.length > 0;
      this.settingsMessage = cleanKey.length > 0 ? 'Search API Key saved.' : 'Search API Key cleared.';
    } catch (err) {
      this.settingsMessage = '搜索 API Key 保存失败，请稍后重试。';
    }
  }

  async clearSearchApiKey(): Promise<void> {
    this.setSearchApiKey('');
    try {
      await this.preferencesService.clearSearchApiKey();
      this.settings.searchApiKeyConfigured = false;
      this.settingsMessage = 'Search API Key cleared.';
    } catch (err) {
      this.settingsMessage = '搜索 API Key 清除失败，请稍后重试。';
    }
  }

  async checkSearchApiKey(): Promise<void> {
    const cleanKey: string = this.searchApiKeyDraft.trim();
    if (cleanKey.length === 0) {
      this.settingsMessage = '请输入 Tavily Search API Key 后再检查。';
      return;
    }
    this.setSearchApiKey(cleanKey);
    this.settingsMessage = 'Checking Tavily Search...';
    const results: SearchResult[] = await this.searchService.search('DeepSeek API docs', {
      maxResults: 1,
      locale: 'zh-CN',
      freshness: 'any'
    });
    if (results.length > 0) {
      this.settingsMessage = 'Search connected. Tavily is available.';
      return;
    }
    const providerMessage: string = this.searchService.getLastErrorMessage();
    this.settingsMessage = providerMessage.length > 0 ? providerMessage : '检查失败，请确认 Tavily API Key 和网络。';
  }

  async checkApiKey(): Promise<void> {
    const cleanKey: string = this.apiKeyDraft.trim();
    if (cleanKey.length === 0) {
      this.settingsMessage = '请输入 API Key 后再检查。';
      return;
    }
    this.setApiKey(cleanKey);
    this.settingsMessage = 'Checking DeepSeek models...';
    const models: ModelListResponse | null = await this.deepSeekService.fetchModels();
    if (models === null) {
      this.settingsMessage = '检查失败，请确认 API Key 和网络。';
      return;
    }
    if (this.hasModel(models, 'deepseek-chat') && this.hasModel(models, 'deepseek-reasoner')) {
      this.settingsMessage = 'Connected. Chat and Reasoner are available.';
      return;
    }
    this.settingsMessage = 'Connected, but required models were not both found.';
  }

  async checkBalance(): Promise<void> {
    if (!this.apiKeyConfigured) {
      this.balanceMessage = '请先配置 DeepSeek API Key。';
      return;
    }
    this.balanceMessage = 'Checking DeepSeek balance...';
    const response: BalanceResponse | null = await this.deepSeekService.fetchBalance();
    if (response === null) {
      this.balanceMessage = '余额查询失败，请确认 API Key 和网络。';
      return;
    }
    this.balanceMessage = this.formatBalance(response);
  }

  async createNewConversation(): Promise<void> {
    const conversation: Conversation = createConversation('New chat');
    this.conversations = [conversation].concat(this.conversations);
    this.currentConversationId = conversation.id;
    this.messages = [];
    this.errorMessage = '';
    await this.persistConversation(conversation);
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

  async deleteConversation(id: string): Promise<void> {
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
      await this.createNewConversation();
    }
    await this.persistDeleteConversation(id);
  }

  async clearAllConversations(): Promise<void> {
    if (this.isLoading) {
      this.settingsMessage = '请先停止当前生成。';
      return;
    }
    try {
      await this.conversationService.deleteAllConversations();
      this.conversations = [];
      this.currentConversationId = '';
      this.messages = [];
      await this.createNewConversation();
      this.settingsMessage = 'All local chats cleared.';
    } catch (err) {
      this.settingsMessage = '清空会话失败，请稍后重试。';
    }
  }

  async resetLocalSettingsAndKeys(): Promise<void> {
    if (this.isLoading) {
      this.settingsMessage = '请先停止当前生成。';
      return;
    }
    try {
      await this.preferencesService.clearApiKey();
      await this.preferencesService.clearSearchApiKey();
      const defaults: AppSettings = await this.preferencesService.resetSettings();
      this.settings = defaults;
      this.applySettings(defaults);
      this.setApiKey('');
      this.setSearchApiKey('');
      this.balanceMessage = '';
      this.settingsMessage = 'Settings and API keys cleared.';
    } catch (err) {
      this.settingsMessage = '重置本地设置失败，请稍后重试。';
    }
  }

  async sendMessage(): Promise<void> {
    const content: string = this.truncateMessageContent(this.inputText.trim());
    if (content.length === 0 || this.isLoading) {
      return;
    }

    const conversationId: string = this.ensureConversation();
    const userMessage: ChatMessage = createMessage(conversationId, MessageRole.USER, content);
    userMessage.status = SendStatus.SUCCESS;

    this.messages = this.messages.concat([userMessage]);
    this.inputText = '';
    this.isLoading = true;
    this.errorMessage = '';
    this.updateCurrentConversation(content);
    await this.persistMessage(userMessage);
    await this.startAssistantReply();
  }

  private async startAssistantReply(): Promise<void> {
    if (this.messages.length === 0) {
      return;
    }
    const conversationId: string = this.ensureConversation();
    const assistantMessage: ChatMessage = createMessage(conversationId, MessageRole.ASSISTANT, '');
    assistantMessage.status = SendStatus.SENDING;
    this.messages = this.messages.concat([assistantMessage]);
    this.isLoading = true;
    this.errorMessage = '';
    this.syncCurrentMessages();
    await this.persistMessage(assistantMessage);

    if (this.webSearchEnabled) {
      await this.sendMessageWithSearch(assistantMessage.id);
      return;
    }

    await this.sendMessageWithoutSearch(assistantMessage.id);
  }

  async editUserMessageAndRegenerate(id: string, content: string): Promise<void> {
    const cleanContent: string = content.trim();
    if (this.isLoading || cleanContent.length === 0) {
      return;
    }
    const targetIndex: number = this.findMessageIndex(id);
    if (targetIndex < 0 || this.messages[targetIndex].role !== MessageRole.USER) {
      return;
    }

    const updated: ChatMessage[] = [];
    const removedIds: string[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      if (i < targetIndex) {
        updated.push(this.messages[i]);
      } else if (i === targetIndex) {
        const message: ChatMessage = this.messages[i];
        message.content = this.truncateMessageContent(cleanContent);
        message.status = SendStatus.SUCCESS;
        message.errorMessage = '';
        message.updatedAt = Date.now();
        updated.push(message);
        await this.persistMessage(message);
      } else {
        removedIds.push(this.messages[i].id);
      }
    }
    this.messages = updated;
    this.syncCurrentMessages();
    await this.persistDeleteMessages(removedIds);
    await this.startAssistantReply();
  }

  async regenerateAssistantMessage(id: string): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const targetIndex: number = this.findMessageIndex(id);
    if (targetIndex < 0 || this.messages[targetIndex].role !== MessageRole.ASSISTANT) {
      return;
    }
    let userIndex: number = -1;
    for (let i = targetIndex - 1; i >= 0; i--) {
      if (this.messages[i].role === MessageRole.USER) {
        userIndex = i;
        break;
      }
    }
    if (userIndex < 0) {
      return;
    }
    const updated: ChatMessage[] = [];
    const removedIds: string[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      if (i <= userIndex) {
        updated.push(this.messages[i]);
      } else {
        removedIds.push(this.messages[i].id);
      }
    }
    this.messages = updated;
    this.syncCurrentMessages();
    await this.persistDeleteMessages(removedIds);
    await this.startAssistantReply();
  }

  async branchConversationFromMessage(id: string): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const targetIndex: number = this.findMessageIndex(id);
    if (targetIndex < 0) {
      return;
    }
    const current: Conversation | null = this.findConversation(this.currentConversationId);
    const branchTitle: string = current === null ? 'Branch' : `${current.title} branch`;
    const branch: Conversation = createConversation(createConversationTitle(branchTitle));
    const copiedMessages: ChatMessage[] = [];
    for (let i = 0; i <= targetIndex; i++) {
      copiedMessages.push(this.cloneMessageForConversation(this.messages[i], branch.id));
    }
    branch.messages = copiedMessages;
    branch.updatedAt = Date.now();
    this.conversations = [branch].concat(this.conversations);
    this.currentConversationId = branch.id;
    this.messages = copiedMessages;
    await this.persistConversation(branch);
    for (let i = 0; i < copiedMessages.length; i++) {
      await this.persistMessage(copiedMessages[i]);
    }
  }

  async continueFromMessage(id: string): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const targetIndex: number = this.findMessageIndex(id);
    if (targetIndex < 0) {
      return;
    }
    const updated: ChatMessage[] = [];
    const removedIds: string[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      if (i <= targetIndex) {
        updated.push(this.messages[i]);
      } else {
        removedIds.push(this.messages[i].id);
      }
    }
    this.messages = updated;
    this.syncCurrentMessages();
    await this.persistDeleteMessages(removedIds);
  }

  private async sendMessageWithoutSearch(assistantMessageId: string): Promise<void> {
    await this.deepSeekService.sendStreamChat(this.toApiMessages(this.messages), this.modelMode, {
      onContent: (chunk: string): void => {
        this.appendAssistantContent(assistantMessageId, chunk);
      },
      onReasoning: (chunk: string): void => {
        this.appendAssistantReasoning(assistantMessageId, chunk);
      },
      onMetadata: (metadata: ResponseMetadata): void => {
        this.updateAssistantMetadata(assistantMessageId, metadata);
      },
      onUsage: (usage: UsageInfo): void => {
        this.updateAssistantUsage(assistantMessageId, usage);
      },
      onError: (message: string): void => {
        this.failAssistantMessage(assistantMessageId, message);
      },
      onComplete: (metadata: ResponseMetadata | null, usage: UsageInfo | null): void => {
        this.completeAssistantMessage(assistantMessageId, metadata, usage);
      }
    });
  }

  private async sendMessageWithSearch(assistantMessageId: string): Promise<void> {
    this.setAssistantContent(assistantMessageId, '正在联网搜索...');
    const transcript: ApiMessage[] = this.toApiMessagesForNewUserRound(this.messages);
    const allSources: SearchResult[] = [];
    const toolRecords: ToolCallRecord[] = [];

    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
      let streamedAnswerStarted: boolean = false;
      const response: ChatCompletionResponse | null = await this.deepSeekService.sendStreamToolRound(transcript, this.modelMode, [createWebSearchToolDefinition()], {
        onContent: (chunk: string): void => {
          if (!streamedAnswerStarted) {
            this.setAssistantContent(assistantMessageId, '');
            streamedAnswerStarted = true;
          }
          this.appendAssistantContent(assistantMessageId, chunk);
        },
        onReasoning: (chunk: string): void => {
          this.appendAssistantReasoning(assistantMessageId, chunk);
        },
        onMetadata: (metadata: ResponseMetadata): void => {
          this.updateAssistantMetadata(assistantMessageId, metadata);
        },
        onUsage: (usage: UsageInfo): void => {
          this.updateAssistantUsage(assistantMessageId, usage);
        },
        onError: (message: string): void => {
          this.failAssistantMessage(assistantMessageId, message);
          this.attachSearchDetails(assistantMessageId, allSources, toolRecords);
        },
        onComplete: (_metadata: ResponseMetadata | null, _usage: UsageInfo | null): void => {
        }
      });
      if (response === null) {
        if (this.errorMessage.length === 0) {
          this.failAssistantMessage(assistantMessageId, '联网对话请求失败，请检查 DeepSeek API Key 和网络。');
        }
        return;
      }

      if (response.metadata.finishReason !== 'tool_calls' || response.toolCalls.length === 0) {
        if (response.content.length === 0) {
          this.setAssistantContent(assistantMessageId, '未生成回答。');
        }
        this.completeAssistantMessage(assistantMessageId, response.metadata, response.usage);
        this.attachSearchDetails(assistantMessageId, allSources, toolRecords);
        return;
      }

      transcript.push({
        role: MessageRole.ASSISTANT,
        content: response.content,
        reasoningContent: response.reasoningContent,
        toolCallsJson: JSON.stringify(response.toolCalls)
      });

      const callCount: number = Math.min(response.toolCalls.length, MAX_TOOL_CALLS_PER_ROUND);
      for (let i = 0; i < callCount; i++) {
        const toolCall: ApiToolCall = response.toolCalls[i];
        const resultJson: string = await this.executeSearchToolCall(assistantMessageId, toolCall, allSources, toolRecords);
        transcript.push({
          role: MessageRole.TOOL,
          content: resultJson,
          toolCallId: toolCall.id
        });
      }
      if (response.toolCalls.length > MAX_TOOL_CALLS_PER_ROUND) {
        const skippedJson: string = createFailedToolResultJson('tool_call_limit', 'Too many tool calls in one round.');
        for (let i = MAX_TOOL_CALLS_PER_ROUND; i < response.toolCalls.length; i++) {
          const skipped: ApiToolCall = response.toolCalls[i];
          transcript.push({
            role: MessageRole.TOOL,
            content: skippedJson,
            toolCallId: skipped.id
          });
          toolRecords.push(createToolCallRecord(assistantMessageId, skipped.id, skipped.function.name, skipped.function.arguments, skippedJson, 'failed'));
        }
      }
    }

    this.failAssistantMessage(assistantMessageId, '联网搜索轮数已达上限，请缩小问题范围后重试。');
    this.attachSearchDetails(assistantMessageId, allSources, toolRecords);
  }

  private async executeSearchToolCall(
    assistantMessageId: string,
    toolCall: ApiToolCall,
    allSources: SearchResult[],
    toolRecords: ToolCallRecord[]
  ): Promise<string> {
    if (toolCall.function.name !== WEB_SEARCH_TOOL_NAME) {
      const resultJson: string = createFailedToolResultJson('unauthorized_tool', 'Only web_search is allowed.');
      toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'failed'));
      return resultJson;
    }

    const parsed: ParsedWebSearchArguments = parseWebSearchArguments(toolCall.function.arguments);
    if (!parsed.ok) {
      const resultJson: string = createFailedToolResultJson('invalid_arguments', parsed.errorMessage);
      toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'failed'));
      return resultJson;
    }

    if (!this.searchApiKeyConfigured) {
      const resultJson: string = createFailedToolResultJson('search_key_missing', 'Search API Key is not configured.');
      toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'failed'));
      return resultJson;
    }

    try {
      const options: SearchOptions = {
        maxResults: Math.min(this.settings.searchMaxResults, MAX_SEARCH_RESULTS_PER_CALL),
        locale: 'zh-CN',
        freshness: parsed.arguments.freshness
      };
      const results: SearchResult[] = await this.searchService.search(parsed.arguments.query, options);
      const providerMessage: string = this.searchService.getLastErrorMessage();
      if (results.length === 0 && providerMessage.length > 0) {
        const resultJson: string = createFailedToolResultJson('search_failed', providerMessage);
        toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'failed'));
        return resultJson;
      }
      const beforeCount: number = allSources.length;
      const mergedSources: SearchResult[] = mergeSearchSources(allSources, results);
      allSources.splice(0, allSources.length);
      for (let i = 0; i < mergedSources.length; i++) {
        allSources.push(mergedSources[i]);
      }
      const indexedResults: SearchResult[] = allSources.slice(beforeCount);
      const resultJson: string = createSearchToolResultJson(parsed.arguments.query, indexedResults);
      toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'success'));
      return resultJson;
    } catch (_err) {
      const resultJson: string = createFailedToolResultJson('search_failed', 'Search provider failed.');
      toolRecords.push(createToolCallRecord(assistantMessageId, toolCall.id, toolCall.function.name, toolCall.function.arguments, resultJson, 'failed'));
      return resultJson;
    }
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
    const latest: ChatMessage | null = this.findMessageByStatus(SendStatus.CANCELED) ?? this.findMessageByStatus(SendStatus.FAILED);
    if (latest !== null) {
      this.persistMessage(latest);
    }
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
      await this.persistDeleteMessage(last.id);
      updated.pop();
    }
    const userMessage: ChatMessage = updated[updated.length - 1];
    if (userMessage.role !== MessageRole.USER) {
      return;
    }
    await this.persistDeleteMessage(userMessage.id);
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
    this.persistDeleteMessage(id);
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
        this.persistRenameConversation(conversations[i]);
        break;
      }
    }
    this.conversations = conversations;
  }

  toggleWebSearch(): void {
    this.webSearchEnabled = !this.webSearchEnabled;
  }

  async setModelMode(mode: ModelMode): Promise<void> {
    this.modelMode = mode;
    this.settings.modelMode = mode;
    try {
      await this.preferencesService.setModelMode(mode);
      this.settingsMessage = 'Model saved.';
    } catch (err) {
      this.settingsMessage = '模型设置保存失败。';
    }
  }

  async setFontSize(size: number): Promise<void> {
    const nextSize: number = Math.min(Math.max(Math.floor(size), 12), 22);
    this.fontSize = nextSize;
    this.settings.fontSize = nextSize;
    await this.saveCurrentSettings('Font size saved.', '字号设置保存失败。');
  }

  async setWebSearchDefault(enabled: boolean): Promise<void> {
    this.webSearchEnabled = enabled;
    this.settings.webSearchDefaultEnabled = enabled;
    await this.saveCurrentSettings('Search default saved.', '联网默认设置保存失败。');
  }

  async setSearchMaxResults(maxResults: number): Promise<void> {
    const nextMax: number = Math.min(Math.max(Math.floor(maxResults), 1), 5);
    this.settings.searchMaxResults = nextMax;
    await this.saveCurrentSettings('Search result limit saved.', '搜索结果数保存失败。');
  }

  async setContextWindowChars(chars: number): Promise<void> {
    this.settings.contextWindowChars = chars >= CONTEXT_EXTENDED_CHAR_BUDGET ? CONTEXT_EXTENDED_CHAR_BUDGET : CONTEXT_STANDARD_CHAR_BUDGET;
    await this.saveCurrentSettings('Context window saved.', '上下文窗口设置保存失败。');
  }

  getSearchMaxResults(): number {
    return this.settings.searchMaxResults;
  }

  getContextWindowChars(): number {
    return this.settings.contextWindowChars;
  }

  getContextWindowText(): string {
    if (this.settings.contextWindowChars >= CONTEXT_EXTENDED_CHAR_BUDGET) {
      return 'Extended 1M-ready';
    }
    return 'Standard 128K';
  }

  getContextUsageText(): string {
    const chars: number = this.estimateContextChars(this.messages);
    return `Current chat approx ${chars} / ${this.settings.contextWindowChars} chars`;
  }

  getCurrentTitle(): string {
    const conversation: Conversation | null = this.findConversation(this.currentConversationId);
    if (conversation === null) {
      return 'New chat';
    }
    return conversation.title;
  }

  getProviderStatusText(): string {
    const deepSeekStatus: string = this.apiKeyConfigured ? 'DeepSeek configured' : 'DeepSeek missing';
    const searchStatus: string = this.searchApiKeyConfigured ? 'Tavily configured' : 'Tavily missing';
    return `${deepSeekStatus}. ${searchStatus}.`;
  }

  getConversationCountText(): string {
    if (this.conversations.length === 1) {
      return '1 local conversation';
    }
    return `${this.conversations.length} local conversations`;
  }

  getCurrentConversationExportName(extension: string): string {
    const suffix: string = extension.trim().length > 0 ? extension.trim() : 'md';
    return `${this.sanitizeFileName(this.getCurrentTitle())}.${suffix}`;
  }

  getCurrentConversationMarkdown(): string {
    const conversation: Conversation | null = this.findConversation(this.currentConversationId);
    const title: string = conversation === null ? 'New chat' : conversation.title;
    const messages: ChatMessage[] = conversation === null ? this.messages : conversation.messages;
    const lines: string[] = [];
    lines.push(`# ${title}`);
    lines.push('');
    lines.push(`Exported from Tomo at ${new Date().toISOString()}.`);
    lines.push('');
    for (let i = 0; i < messages.length; i++) {
      const message: ChatMessage = messages[i];
      lines.push(`## ${this.toMarkdownRole(message.role)}`);
      lines.push('');
      if (message.reasoningContent.length > 0) {
        lines.push('<details>');
        lines.push('<summary>Reasoning</summary>');
        lines.push('');
        lines.push(message.reasoningContent);
        lines.push('');
        lines.push('</details>');
        lines.push('');
      }
      if (message.content.length > 0) {
        lines.push(message.content);
        lines.push('');
      }
      if (message.errorMessage.length > 0) {
        lines.push(`Error: ${message.errorMessage}`);
        lines.push('');
      }
      if (message.searchSources.length > 0) {
        lines.push('### Sources');
        lines.push('');
        for (let j = 0; j < message.searchSources.length; j++) {
          const source: SearchResult = message.searchSources[j];
          lines.push(`${source.index}. [${source.title}](${source.url})`);
        }
        lines.push('');
      }
    }
    return lines.join('\n');
  }

  getCurrentConversationJson(): string {
    const conversation: Conversation | null = this.findConversation(this.currentConversationId);
    const title: string = conversation === null ? 'New chat' : conversation.title;
    const messages: ChatMessage[] = conversation === null ? this.messages : conversation.messages;
    const payload: Conversation = new Conversation();
    payload.id = conversation === null ? this.currentConversationId : conversation.id;
    payload.title = title;
    payload.createdAt = conversation === null ? 0 : conversation.createdAt;
    payload.updatedAt = conversation === null ? Date.now() : conversation.updatedAt;
    payload.messages = messages;
    return JSON.stringify(payload, null, 2);
  }

  private applySettings(settings: AppSettings): void {
    this.modelMode = settings.modelMode;
    this.fontSize = settings.fontSize;
    this.webSearchEnabled = settings.webSearchDefaultEnabled;
    this.backgroundEnabled = settings.backgroundEnabled;
    this.backgroundImageUri = settings.backgroundImageUri;
    this.backgroundOpacity = settings.backgroundOpacity;
    this.backgroundBlurRadius = settings.backgroundBlurRadius;
    this.apiKeyConfigured = settings.apiKeyConfigured;
    this.searchApiKeyConfigured = settings.searchApiKeyConfigured;
  }

  private async restoreApiKey(): Promise<void> {
    try {
      const apiKey: string = await this.preferencesService.loadApiKey();
      this.setApiKey(apiKey);
      this.apiKeyConfigured = apiKey.length > 0;
    } catch (err) {
      this.setApiKey('');
    }
  }

  private async restoreSearchApiKey(): Promise<void> {
    try {
      const apiKey: string = await this.preferencesService.loadSearchApiKey();
      this.setSearchApiKey(apiKey);
      this.searchApiKeyConfigured = apiKey.length > 0;
    } catch (err) {
      this.setSearchApiKey('');
    }
  }

  private hasModel(models: ModelListResponse, id: string): boolean {
    for (let i = 0; i < models.data.length; i++) {
      const model: ModelInfo = models.data[i];
      if (model.id === id) {
        return true;
      }
    }
    return false;
  }

  private formatBalance(response: BalanceResponse): string {
    const availability: string = response.isAvailable ? 'Account available' : 'Account unavailable';
    if (response.balanceInfos.length === 0) {
      return `${availability}. No balance entries returned.`;
    }
    const parts: string[] = [];
    for (let i = 0; i < response.balanceInfos.length; i++) {
      const info: BalanceInfo = response.balanceInfos[i];
      parts.push(`${info.currency} ${info.totalBalance}`);
    }
    return `${availability}. Balance: ${parts.join(', ')}`;
  }

  private toMarkdownRole(role: MessageRole): string {
    if (role === MessageRole.USER) {
      return 'User';
    }
    if (role === MessageRole.ASSISTANT) {
      return 'Assistant';
    }
    if (role === MessageRole.SYSTEM) {
      return 'System';
    }
    return 'Tool';
  }

  private sanitizeFileName(name: string): string {
    const clean: string = name.trim().replace(/[\\/:*?"<>|]/g, '_');
    if (clean.length === 0) {
      return 'tomo-conversation';
    }
    if (clean.length > 48) {
      return clean.substring(0, 48);
    }
    return clean;
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
    return this.toBudgetedApiMessages(messages, true);
  }

  private toApiMessagesForNewUserRound(messages: ChatMessage[]): ApiMessage[] {
    return this.toBudgetedApiMessages(messages, false);
  }

  private toBudgetedApiMessages(messages: ChatMessage[], includeReasoning: boolean): ApiMessage[] {
    const selected: ChatMessage[] = [];
    let charBudget: number = Math.max(this.settings.contextWindowChars, MAX_MESSAGE_CHARS);
    let includedCount: number = 0;
    for (let i = messages.length - 1; i >= 0; i--) {
      const message: ChatMessage = messages[i];
      if (message.status === SendStatus.FAILED || message.status === SendStatus.CANCELED || message.status === SendStatus.SENDING) {
        continue;
      }
      const messageChars: number = this.estimateMessageChars(message, includeReasoning);
      if (selected.length > 0 && (charBudget - messageChars < 0 || includedCount >= MAX_RECENT_MESSAGES && this.settings.contextWindowChars <= CONTEXT_STANDARD_CHAR_BUDGET)) {
        break;
      }
      selected.unshift(message);
      charBudget -= messageChars;
      includedCount++;
    }
    const apiMessages: ApiMessage[] = [];
    for (let i = 0; i < selected.length; i++) {
      const message: ChatMessage = selected[i];
      apiMessages.push({
        role: message.role,
        content: message.content,
        reasoningContent: includeReasoning ? message.reasoningContent : ''
      });
    }
    return apiMessages;
  }

  private estimateContextChars(messages: ChatMessage[]): number {
    let chars: number = 0;
    for (let i = 0; i < messages.length; i++) {
      const message: ChatMessage = messages[i];
      if (message.status === SendStatus.FAILED || message.status === SendStatus.CANCELED || message.status === SendStatus.SENDING) {
        continue;
      }
      chars += this.estimateMessageChars(message, false);
    }
    return chars;
  }

  private estimateMessageChars(message: ChatMessage, includeReasoning: boolean): number {
    let chars: number = message.content.length + message.role.length + 8;
    if (includeReasoning) {
      chars += message.reasoningContent.length;
    }
    if (message.toolCalls.length > 0) {
      chars += JSON.stringify(message.toolCalls).length;
    }
    return chars;
  }

  private truncateMessageContent(content: string): string {
    if (content.length <= MAX_MESSAGE_CHARS) {
      return content;
    }
    return content.substring(0, MAX_MESSAGE_CHARS);
  }

  private findMessageIndex(id: string): number {
    for (let i = 0; i < this.messages.length; i++) {
      if (this.messages[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  private cloneMessageForConversation(message: ChatMessage, conversationId: string): ChatMessage {
    const cloned: ChatMessage = createMessage(conversationId, message.role, message.content);
    cloned.reasoningContent = message.reasoningContent;
    cloned.status = message.status;
    cloned.errorMessage = message.errorMessage;
    cloned.responseId = message.responseId;
    cloned.model = message.model;
    cloned.finishReason = message.finishReason;
    cloned.systemFingerprint = message.systemFingerprint;
    cloned.promptTokens = message.promptTokens;
    cloned.completionTokens = message.completionTokens;
    cloned.totalTokens = message.totalTokens;
    cloned.reasoningTokens = message.reasoningTokens;
    cloned.cacheHitTokens = message.cacheHitTokens;
    cloned.cacheMissTokens = message.cacheMissTokens;
    cloned.searchSources = message.searchSources.slice();
    const toolCalls: ToolCallRecord[] = [];
    for (let i = 0; i < message.toolCalls.length; i++) {
      const record: ToolCallRecord = message.toolCalls[i];
      toolCalls.push(createToolCallRecord(cloned.id, record.toolCallId, record.name, record.argumentsJson, record.resultJson, record.status));
    }
    cloned.toolCalls = toolCalls;
    cloned.createdAt = message.createdAt;
    cloned.updatedAt = Date.now();
    return cloned;
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
    }, true);
  }

  private setAssistantContent(id: string, content: string): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.content = content;
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
    }, true);
  }

  private completeSearchAssistantMessage(
    id: string,
    response: ChatCompletionResponse,
    sources: SearchResult[],
    toolCalls: ToolCallRecord[]
  ): void {
    this.isLoading = false;
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.content = response.content.length > 0 ? response.content : '未生成回答。';
      message.reasoningContent = response.reasoningContent;
      message.responseId = response.metadata.responseId;
      message.model = response.metadata.model;
      message.finishReason = response.metadata.finishReason;
      message.systemFingerprint = response.metadata.systemFingerprint;
      message.promptTokens = response.usage.promptTokens;
      message.completionTokens = response.usage.completionTokens;
      message.totalTokens = response.usage.totalTokens;
      message.reasoningTokens = response.usage.reasoningTokens;
      message.cacheHitTokens = response.usage.cacheHitTokens;
      message.cacheMissTokens = response.usage.cacheMissTokens;
      message.searchSources = sources;
      message.toolCalls = toolCalls;
      message.status = SendStatus.SUCCESS;
      message.errorMessage = '';
    }, true);
  }

  private attachSearchDetails(id: string, sources: SearchResult[], toolCalls: ToolCallRecord[]): void {
    this.updateAssistantMessage(id, (message: ChatMessage): void => {
      message.searchSources = sources;
      message.toolCalls = toolCalls;
    }, true);
  }

  private updateAssistantMessage(id: string, updater: (message: ChatMessage) => void, forcePersist: boolean = false): void {
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
    this.persistAssistantMessage(updated, id, forcePersist);
  }

  private persistAssistantMessage(messages: ChatMessage[], id: string, force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastAssistantPersistAt < 750) {
      return;
    }
    const message: ChatMessage | null = this.findMessageIn(messages, id);
    if (message === null) {
      return;
    }
    this.lastAssistantPersistAt = now;
    this.persistMessage(message);
  }

  private async persistConversation(conversation: Conversation): Promise<void> {
    try {
      await this.conversationService.createConversation(conversation);
    } catch (err) {
      this.errorMessage = '会话保存失败。';
    }
  }

  private async persistRenameConversation(conversation: Conversation): Promise<void> {
    try {
      await this.conversationService.renameConversation(conversation.id, conversation.title, conversation.updatedAt);
    } catch (err) {
      this.errorMessage = '会话标题保存失败。';
    }
  }

  private async persistDeleteConversation(id: string): Promise<void> {
    try {
      await this.conversationService.deleteConversation(id);
    } catch (err) {
      this.errorMessage = '会话删除失败。';
    }
  }

  private async persistMessage(message: ChatMessage): Promise<void> {
    try {
      await this.conversationService.updateMessage(message);
    } catch (err) {
      this.errorMessage = '消息保存失败。';
    }
  }

  private async persistDeleteMessage(id: string): Promise<void> {
    try {
      await this.conversationService.deleteMessage(id);
    } catch (err) {
      this.errorMessage = '消息删除失败。';
    }
  }

  private async persistDeleteMessages(ids: string[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    try {
      await this.conversationService.deleteMessages(ids);
    } catch (err) {
      this.errorMessage = '消息删除失败。';
    }
  }

  private async saveCurrentSettings(successMessage: string, failedMessage: string): Promise<void> {
    try {
      this.settings.apiKeyConfigured = this.apiKeyConfigured;
      this.settings.searchApiKeyConfigured = this.searchApiKeyConfigured;
      await this.preferencesService.saveSettings(this.settings);
      this.settingsMessage = successMessage;
    } catch (err) {
      this.settingsMessage = failedMessage;
    }
  }

  private findMessageByStatus(status: SendStatus): ChatMessage | null {
    for (let i = this.messages.length - 1; i >= 0; i--) {
      if (this.messages[i].status === status) {
        return this.messages[i];
      }
    }
    return null;
  }

  private findMessageIn(messages: ChatMessage[], id: string): ChatMessage | null {
    for (let i = 0; i < messages.length; i++) {
      if (messages[i].id === id) {
        return messages[i];
      }
    }
    return null;
  }
}
