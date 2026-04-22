import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { relationalStore } from '@kit.ArkData';
import { ChatMessage, Conversation, MessageRole, SendStatus } from '../models/ChatModels';
import { SearchResult, ToolCallRecord } from '../models/SearchModels';

const DB_NAME: string = 'deepseek_chat.db';
const DB_VERSION: number = 1;

const SQL_CREATE_CONVERSATIONS: string =
  'CREATE TABLE IF NOT EXISTS conversations (' +
    'id TEXT PRIMARY KEY,' +
    'title TEXT NOT NULL,' +
    'created_at INTEGER NOT NULL,' +
    'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_MESSAGES: string =
  'CREATE TABLE IF NOT EXISTS messages (' +
    'id TEXT PRIMARY KEY,' +
    'conversation_id TEXT NOT NULL,' +
    'role TEXT NOT NULL,' +
    'content TEXT NOT NULL,' +
    'reasoning_content TEXT NOT NULL DEFAULT \'\',' +
    'status TEXT NOT NULL,' +
    'error_message TEXT NOT NULL DEFAULT \'\',' +
    'response_id TEXT NOT NULL DEFAULT \'\',' +
    'model TEXT NOT NULL DEFAULT \'\',' +
    'finish_reason TEXT NOT NULL DEFAULT \'\',' +
    'system_fingerprint TEXT NOT NULL DEFAULT \'\',' +
    'prompt_tokens INTEGER NOT NULL DEFAULT 0,' +
    'completion_tokens INTEGER NOT NULL DEFAULT 0,' +
    'total_tokens INTEGER NOT NULL DEFAULT 0,' +
    'reasoning_tokens INTEGER NOT NULL DEFAULT 0,' +
    'cache_hit_tokens INTEGER NOT NULL DEFAULT 0,' +
    'cache_miss_tokens INTEGER NOT NULL DEFAULT 0,' +
    'created_at INTEGER NOT NULL,' +
    'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_MESSAGE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_messages_conversation_time ON messages(conversation_id, created_at)';

const SQL_CREATE_TOOL_CALLS: string =
  'CREATE TABLE IF NOT EXISTS message_tool_calls (' +
    'id TEXT PRIMARY KEY,' +
    'message_id TEXT NOT NULL,' +
    'tool_call_id TEXT NOT NULL,' +
    'name TEXT NOT NULL,' +
    'arguments_json TEXT NOT NULL DEFAULT \'\',' +
    'result_json TEXT NOT NULL DEFAULT \'\',' +
    'status TEXT NOT NULL,' +
    'created_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_SEARCH_SOURCES: string =
  'CREATE TABLE IF NOT EXISTS message_search_sources (' +
    'id TEXT PRIMARY KEY,' +
    'message_id TEXT NOT NULL,' +
    'tool_call_id TEXT NOT NULL DEFAULT \'\',' +
    'title TEXT NOT NULL,' +
    'url TEXT NOT NULL,' +
    'snippet TEXT NOT NULL,' +
    'published_at TEXT NOT NULL DEFAULT \'\',' +
    'source TEXT NOT NULL DEFAULT \'\',' +
    'rank INTEGER NOT NULL,' +
    'created_at INTEGER NOT NULL' +
  ')';

export class ConversationRdbService {
  private store: relationalStore.RdbStore | null = null;

  async init(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    this.store = await this.openStore(context);
    await this.createSchema(this.store);
  }

  async insertConversation(conversation: Conversation): Promise<void> {
    const store = this.requireStore();
    await store.execute(
      'INSERT OR REPLACE INTO conversations (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)',
      [conversation.id, conversation.title, conversation.createdAt, conversation.updatedAt]
    );
  }

  async updateConversationTitle(id: string, title: string, updatedAt: number): Promise<void> {
    const store = this.requireStore();
    await store.execute(
      'UPDATE conversations SET title = ?, updated_at = ? WHERE id = ?',
      [title, updatedAt, id]
    );
  }

  async deleteConversation(id: string): Promise<void> {
    const store = this.requireStore();
    await store.execute(
      'DELETE FROM message_search_sources WHERE message_id IN (SELECT id FROM messages WHERE conversation_id = ?)',
      [id]
    );
    await store.execute(
      'DELETE FROM message_tool_calls WHERE message_id IN (SELECT id FROM messages WHERE conversation_id = ?)',
      [id]
    );
    await store.execute('DELETE FROM messages WHERE conversation_id = ?', [id]);
    await store.execute('DELETE FROM conversations WHERE id = ?', [id]);
  }

  async insertMessage(message: ChatMessage): Promise<void> {
    const store = this.requireStore();
    await store.execute(
      'INSERT OR REPLACE INTO messages (' +
        'id, conversation_id, role, content, reasoning_content, status, error_message, response_id, model, finish_reason, system_fingerprint, ' +
        'prompt_tokens, completion_tokens, total_tokens, reasoning_tokens, cache_hit_tokens, cache_miss_tokens, created_at, updated_at' +
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      this.messageArgs(message)
    );
    await this.replaceMessageDetails(message);
  }

  async updateMessage(message: ChatMessage): Promise<void> {
    const store = this.requireStore();
    await store.execute(
      'UPDATE messages SET ' +
        'conversation_id = ?, role = ?, content = ?, reasoning_content = ?, status = ?, error_message = ?, response_id = ?, model = ?, ' +
        'finish_reason = ?, system_fingerprint = ?, prompt_tokens = ?, completion_tokens = ?, total_tokens = ?, reasoning_tokens = ?, ' +
        'cache_hit_tokens = ?, cache_miss_tokens = ?, created_at = ?, updated_at = ? WHERE id = ?',
      [
        message.conversationId,
        message.role,
        message.content,
        message.reasoningContent,
        message.status,
        message.errorMessage,
        message.responseId,
        message.model,
        message.finishReason,
        message.systemFingerprint,
        message.promptTokens,
        message.completionTokens,
        message.totalTokens,
        message.reasoningTokens,
        message.cacheHitTokens,
        message.cacheMissTokens,
        message.createdAt,
        message.updatedAt,
        message.id
      ]
    );
    await this.replaceMessageDetails(message);
  }

  async deleteMessage(id: string): Promise<void> {
    const store = this.requireStore();
    await store.execute('DELETE FROM message_search_sources WHERE message_id = ?', [id]);
    await store.execute('DELETE FROM message_tool_calls WHERE message_id = ?', [id]);
    await store.execute('DELETE FROM messages WHERE id = ?', [id]);
  }

  async deleteMessages(ids: string[]): Promise<void> {
    for (let i = 0; i < ids.length; i++) {
      await this.deleteMessage(ids[i]);
    }
  }

  async loadConversationsWithMessages(): Promise<Conversation[]> {
    const store = this.requireStore();
    const conversations: Conversation[] = [];
    const resultSet = await store.querySql(
      'SELECT id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC'
    );
    try {
      while (resultSet.goToNextRow()) {
        const conversation: Conversation = new Conversation();
        conversation.id = resultSet.getString(resultSet.getColumnIndex('id'));
        conversation.title = resultSet.getString(resultSet.getColumnIndex('title'));
        conversation.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        conversation.updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at'));
        conversation.messages = await this.loadMessages(conversation.id);
        conversations.push(conversation);
      }
    } finally {
      resultSet.close();
    }
    return conversations;
  }

  private async loadMessages(conversationId: string): Promise<ChatMessage[]> {
    const store = this.requireStore();
    const messages: ChatMessage[] = [];
    const resultSet = await store.querySql(
      'SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC',
      [conversationId]
    );
    try {
      while (resultSet.goToNextRow()) {
        const message: ChatMessage = new ChatMessage();
        message.id = resultSet.getString(resultSet.getColumnIndex('id'));
        message.conversationId = resultSet.getString(resultSet.getColumnIndex('conversation_id'));
        message.role = this.toMessageRole(resultSet.getString(resultSet.getColumnIndex('role')));
        message.content = resultSet.getString(resultSet.getColumnIndex('content'));
        message.reasoningContent = resultSet.getString(resultSet.getColumnIndex('reasoning_content'));
        message.status = this.toSendStatus(resultSet.getString(resultSet.getColumnIndex('status')));
        message.errorMessage = resultSet.getString(resultSet.getColumnIndex('error_message'));
        message.responseId = resultSet.getString(resultSet.getColumnIndex('response_id'));
        message.model = resultSet.getString(resultSet.getColumnIndex('model'));
        message.finishReason = resultSet.getString(resultSet.getColumnIndex('finish_reason'));
        message.systemFingerprint = resultSet.getString(resultSet.getColumnIndex('system_fingerprint'));
        message.promptTokens = resultSet.getLong(resultSet.getColumnIndex('prompt_tokens'));
        message.completionTokens = resultSet.getLong(resultSet.getColumnIndex('completion_tokens'));
        message.totalTokens = resultSet.getLong(resultSet.getColumnIndex('total_tokens'));
        message.reasoningTokens = resultSet.getLong(resultSet.getColumnIndex('reasoning_tokens'));
        message.cacheHitTokens = resultSet.getLong(resultSet.getColumnIndex('cache_hit_tokens'));
        message.cacheMissTokens = resultSet.getLong(resultSet.getColumnIndex('cache_miss_tokens'));
        message.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        message.updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at'));
        message.searchSources = await this.loadSearchSources(message.id);
        message.toolCalls = await this.loadToolCalls(message.id);
        messages.push(message);
      }
    } finally {
      resultSet.close();
    }
    return messages;
  }

  private async loadSearchSources(messageId: string): Promise<SearchResult[]> {
    const store = this.requireStore();
    const sources: SearchResult[] = [];
    const resultSet = await store.querySql(
      'SELECT title, url, snippet, published_at, source FROM message_search_sources WHERE message_id = ? ORDER BY rank ASC',
      [messageId]
    );
    try {
      while (resultSet.goToNextRow()) {
        sources.push({
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          url: resultSet.getString(resultSet.getColumnIndex('url')),
          snippet: resultSet.getString(resultSet.getColumnIndex('snippet')),
          publishedAt: resultSet.getString(resultSet.getColumnIndex('published_at')),
          source: resultSet.getString(resultSet.getColumnIndex('source'))
        });
      }
    } finally {
      resultSet.close();
    }
    return sources;
  }

  private async loadToolCalls(messageId: string): Promise<ToolCallRecord[]> {
    const store = this.requireStore();
    const records: ToolCallRecord[] = [];
    const resultSet = await store.querySql(
      'SELECT id, message_id, tool_call_id, name, arguments_json, result_json, status, created_at FROM message_tool_calls WHERE message_id = ? ORDER BY created_at ASC',
      [messageId]
    );
    try {
      while (resultSet.goToNextRow()) {
        records.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          messageId: resultSet.getString(resultSet.getColumnIndex('message_id')),
          toolCallId: resultSet.getString(resultSet.getColumnIndex('tool_call_id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          argumentsJson: resultSet.getString(resultSet.getColumnIndex('arguments_json')),
          resultJson: resultSet.getString(resultSet.getColumnIndex('result_json')),
          status: resultSet.getString(resultSet.getColumnIndex('status')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } finally {
      resultSet.close();
    }
    return records;
  }

  private async replaceMessageDetails(message: ChatMessage): Promise<void> {
    const store = this.requireStore();
    await store.execute('DELETE FROM message_search_sources WHERE message_id = ?', [message.id]);
    await store.execute('DELETE FROM message_tool_calls WHERE message_id = ?', [message.id]);
    for (let i = 0; i < message.searchSources.length; i++) {
      const source: SearchResult = message.searchSources[i];
      await store.execute(
        'INSERT INTO message_search_sources (id, message_id, tool_call_id, title, url, snippet, published_at, source, rank, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [`src_${message.id}_${i}`, message.id, '', source.title, source.url, source.snippet, source.publishedAt, source.source, i, Date.now()]
      );
    }
    for (let i = 0; i < message.toolCalls.length; i++) {
      const record: ToolCallRecord = message.toolCalls[i];
      await store.execute(
        'INSERT OR REPLACE INTO message_tool_calls (id, message_id, tool_call_id, name, arguments_json, result_json, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [record.id, record.messageId, record.toolCallId, record.name, record.argumentsJson, record.resultJson, record.status, record.createdAt]
      );
    }
  }

  private messageArgs(message: ChatMessage): relationalStore.ValueType[] {
    return [
      message.id,
      message.conversationId,
      message.role,
      message.content,
      message.reasoningContent,
      message.status,
      message.errorMessage,
      message.responseId,
      message.model,
      message.finishReason,
      message.systemFingerprint,
      message.promptTokens,
      message.completionTokens,
      message.totalTokens,
      message.reasoningTokens,
      message.cacheHitTokens,
      message.cacheMissTokens,
      message.createdAt,
      message.updatedAt
    ];
  }

  private async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S2
    };
    return new Promise<relationalStore.RdbStore>((resolve, reject) => {
      relationalStore.getRdbStore(context, config, (err: BusinessError, store: relationalStore.RdbStore) => {
        if (err) {
          reject(new Error(`Failed to open conversation database: ${err.message}`));
          return;
        }
        resolve(store);
      });
    });
  }

  private async createSchema(store: relationalStore.RdbStore): Promise<void> {
    await store.execute(SQL_CREATE_CONVERSATIONS);
    await store.execute(SQL_CREATE_MESSAGES);
    await store.execute(SQL_CREATE_MESSAGE_INDEX);
    await store.execute(SQL_CREATE_TOOL_CALLS);
    await store.execute(SQL_CREATE_SEARCH_SOURCES);
    store.version = DB_VERSION;
  }

  private requireStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('ConversationRdbService must be initialized before use.');
    }
    return this.store;
  }

  private toMessageRole(value: string): MessageRole {
    if (value === MessageRole.ASSISTANT) {
      return MessageRole.ASSISTANT;
    }
    if (value === MessageRole.SYSTEM) {
      return MessageRole.SYSTEM;
    }
    if (value === MessageRole.TOOL) {
      return MessageRole.TOOL;
    }
    return MessageRole.USER;
  }

  private toSendStatus(value: string): SendStatus {
    if (value === SendStatus.SENDING) {
      return SendStatus.SENDING;
    }
    if (value === SendStatus.SUCCESS) {
      return SendStatus.SUCCESS;
    }
    if (value === SendStatus.FAILED) {
      return SendStatus.FAILED;
    }
    if (value === SendStatus.CANCELED) {
      return SendStatus.CANCELED;
    }
    return SendStatus.IDLE;
  }
}
