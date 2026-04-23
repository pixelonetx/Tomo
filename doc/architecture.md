# 技术架构

## 技术栈

- HarmonyOS ArkTS。
- ArkUI 声明式 UI。
- 优先使用成熟的 ArkUI `@Component` 体系。
- 第一版不要强制使用 `@ComponentV2`；仅在 SDK、DevEco Studio 和团队实现习惯都稳定支持时局部采用。
- `@kit.NetworkKit` 处理 DeepSeek HTTP / SSE 和联网搜索 HTTP。
- `@kit.ArkData` Preferences 处理用户首选项。
- RDB 处理会话、消息、搜索来源和工具调用记录。
- `@kit.AbilityKit` 处理生命周期和窗口。
- `@kit.CoreFileKit` / picker 处理用户明确选择的文件。
- `@kit.MediaLibraryKit` 处理图片选择。

## 推荐目录结构

```text
entry/src/main/ets/
  entryability/
    EntryAbility.ets
  models/
    ApiModels.ets
    ChatModels.ets
    SettingsModels.ets
  pages/
    Index.ets
    SettingsPage.ets
  services/
    DeepSeekService.ets
    ConversationService.ets
    ConversationRdbService.ets
    PreferencesService.ets
    BackgroundService.ets
    AttachmentService.ets
    OcrService.ets
    SearchService.ets
    SearchToolRunner.ets
    SpeechInputService.ets
  ui/
    ChatInputBar.ets
    MessageBubble.ets
    MarkdownView.ets
    CodeBlockView.ets
    SidebarPanel.ets
    ApiKeySheet.ets
    EmptyStateView.ets
    FloatingMenu.ets
  shared/
    Constants.ets
    RuntimeHiLog.ets
    Result.ets
```

目录结构保持收敛，不要为第一版预留通用扩展平台、执行环境或自动化编排模块。

## HarmonyOS 原生能力边界

平台能力要服务聊天主线：

- 用户偏好使用 Preferences。
- 会话历史使用 RDB。
- 首页沉浸式使用安全区友好的绘制延伸，不隐藏系统栏。
- 页面跳转优先使用 Navigation / NavPathStack；第一版页面少，可以先用 Sheet 承载设置。
- 第一版使用成熟 `@Component` 状态管理，不强制 `@ComponentV2`。

详细约束见 `harmonyos-platform-notes.md`。

## 数据模型

### Conversation

```ts
export class Conversation {
  id: string
  title: string
  createdAt: number
  updatedAt: number
  messages: ChatMessage[]
}
```

### ChatMessage

```ts
export enum MessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system'
}

export enum SendStatus {
  IDLE = 'idle',
  SENDING = 'sending',
  SUCCESS = 'success',
  FAILED = 'failed',
  CANCELED = 'canceled'
}

export class ChatMessage {
  id: string
  conversationId: string
  role: MessageRole
  content: string
  reasoningContent: string
  status: SendStatus
  errorMessage: string
  responseId: string
  model: string
  finishReason: string
  systemFingerprint: string
  promptTokens: number
  completionTokens: number
  totalTokens: number
  reasoningTokens: number
  cacheHitTokens: number
  cacheMissTokens: number
  createdAt: number
  updatedAt: number
}
```

这些元数据来自 DeepSeek 响应，不进入主消息正文。它们用于消息详情、设置页诊断、错误排查和轻量 usage 统计。

### ApiModels

```ts
export interface UsageInfo {
  promptTokens: number
  completionTokens: number
  totalTokens: number
  reasoningTokens: number
  cacheHitTokens: number
  cacheMissTokens: number
}

export interface ResponseMetadata {
  responseId: string
  model: string
  created: number
  systemFingerprint: string
  finishReason: string
}

export interface ModelInfo {
  id: string
  object: string
  ownedBy: string
}

export interface BalanceInfo {
  currency: string
  totalBalance: string
  grantedBalance: string
  toppedUpBalance: string
}

export interface SearchResult {
  title: string
  url: string
  snippet: string
  publishedAt: string
  source: string
}

export interface ToolCallRecord {
  id: string
  messageId: string
  toolCallId: string
  name: string
  argumentsJson: string
  resultJson: string
  status: 'success' | 'failed'
  createdAt: number
}
```

### Settings

```ts
export interface AppSettings {
  apiKeyConfigured: boolean
  modelMode: 'chat' | 'reasoner'
  themeMode: 'system' | 'light' | 'dark'
  fontSize: number
  backgroundEnabled: boolean
  backgroundImageUri: string
  backgroundBlurRadius: number
  backgroundOpacity: number
  webSearchDefaultEnabled: boolean
  searchProvider: string
  searchApiKeyConfigured: boolean
  searchMaxResults: number
}
```

## 数据库设计

使用 RDB，不要用“每次全量重写所有会话”的方式。

### conversations

```sql
CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### messages

```sql
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  reasoning_content TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL,
  error_message TEXT NOT NULL DEFAULT '',
  response_id TEXT NOT NULL DEFAULT '',
  model TEXT NOT NULL DEFAULT '',
  finish_reason TEXT NOT NULL DEFAULT '',
  system_fingerprint TEXT NOT NULL DEFAULT '',
  prompt_tokens INTEGER NOT NULL DEFAULT 0,
  completion_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,
  reasoning_tokens INTEGER NOT NULL DEFAULT 0,
  cache_hit_tokens INTEGER NOT NULL DEFAULT 0,
  cache_miss_tokens INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### 推荐索引

```sql
CREATE INDEX IF NOT EXISTS idx_messages_conversation_time
ON messages(conversation_id, created_at);
```

### message_tool_calls

```sql
CREATE TABLE IF NOT EXISTS message_tool_calls (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  tool_call_id TEXT NOT NULL,
  name TEXT NOT NULL,
  arguments_json TEXT NOT NULL DEFAULT '',
  result_json TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
```

### message_search_sources

搜索来源不要塞进消息正文，单独持久化。

```sql
CREATE TABLE IF NOT EXISTS message_search_sources (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  tool_call_id TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  snippet TEXT NOT NULL,
  published_at TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT '',
  rank INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

删除 assistant message 时必须同步删除对应 tool calls 和 sources。

## 持久化规则

### Preferences

用户首选项必须由 `PreferencesService` 统一管理。

存入 Preferences：

- `modelMode`
- `themeMode`
- `fontSize`
- `backgroundEnabled`
- `backgroundImageUri`
- `backgroundBlurRadius`
- `backgroundOpacity`
- `webSearchDefaultEnabled`
- `searchProvider`
- `searchMaxResults`
- `apiKeyConfigured`
- `searchApiKeyConfigured`

不存入 Preferences：

- 会话和消息。
- reasoning 内容。
- 搜索来源。
- tool call 记录。
- 大段附件文本。

Preferences 写入后必须统一 flush。API Key 若暂时本地保存，需要在设置页明确本地保存边界；后续优先迁移到系统安全存储。

### RDB

- 新建会话：insert conversation。
- 更新标题：update conversation title / updated_at。
- 新增消息：insert message。
- 流式更新：节流 update message，不要每 token 写库。
- 完成消息：update final content/status。
- 删除消息：delete message by id。
- 删除消息相关工具调用和搜索来源。
- 删除会话：transaction 删除 conversation 和 messages。
- 重试消息：删除失败 assistant 消息，保留对应用户消息，重新生成。

必须避免：

- replaceAll。
- 先删全表再重插。
- 删除消息后数据库残留。
- 流式每个 token 都写数据库。

## DeepSeekService

### 职责

- 管理 API Key。
- 发起 chat completions。
- 解析 SSE。
- 支持取消当前请求。
- 处理错误码。
- 返回 content、reasoning_content、usage、finish_reason、responseId、model、system_fingerprint。
- 查询模型列表。
- 查询余额。

### 接口建议

```ts
export interface StreamCallback {
  onContent: (chunk: string) => void
  onReasoning: (chunk: string) => void
  onMetadata: (metadata: ResponseMetadata) => void
  onUsage: (usage: UsageInfo) => void
  onError: (message: string) => void
  onComplete: (metadata: ResponseMetadata | null, usage: UsageInfo | null) => void
}

export class DeepSeekService {
  setApiKey(key: string): void
  cancelRequest(): void
  sendStreamChat(messages: ApiMessage[], mode: ModelMode, callback: StreamCallback): Promise<void>
  sendStreamToolRound(messages: ApiMessage[], mode: ModelMode, tools: ApiToolDefinition[], callback: StreamCallback): Promise<ChatCompletionResponse | null>
  sendToolRound(messages: ApiMessage[], tools: ApiToolDefinition[]): Promise<ChatCompletionResponse | null>
  sendChat(messages: ApiMessage[], mode: ModelMode): Promise<ChatCompletionResponse | null>
  fetchModels(): Promise<ModelListResponse | null>
  fetchBalance(): Promise<BalanceResponse | null>
}
```

## SearchService / SearchToolRunner

联网搜索使用 DeepSeek Tool Calls，但只开放内置 `web_search`。不要创建任意工具执行平台。

### 职责

- 读取搜索 provider 配置。
- 发起搜索请求。
- 解析搜索 provider 响应。
- 清洗标题、URL、snippet。
- URL 去重。
- 限制最多 5 条结果。
- 将搜索结果封装成 `role=tool` message。
- 执行最多 3 轮工具循环。
- 工具轮优先使用流式 `tool_choice=auto`，解析 `delta.tool_calls`；若该轮直接输出 content，则直接作为最终回答完成，避免额外 final probe。

### 接口建议

```ts
export interface SearchOptions {
  maxResults: number
  locale: string
  freshness: 'any' | 'day' | 'week' | 'month'
}

export class SearchService {
  setApiKey(key: string): void
  search(query: string, options: SearchOptions): Promise<SearchResult[]>
}

export class SearchToolRunner {
  run(messages: ApiMessage[], mode: ModelMode): Promise<SearchToolRunResult>
}
```

### 工具循环

推荐硬限制：

```ts
const MAX_TOOL_ROUNDS = 3
const MAX_TOOL_CALLS_PER_ROUND = 2
const MAX_SEARCH_RESULTS_PER_CALL = 5
```

流程：

- `deepseek-chat + 联网`：使用 `tools=[web_search]`、`tool_choice=auto`。
- 当 `finish_reason=tool_calls` 时，校验工具名和参数，执行搜索，追加 `role=tool` message。
- 达到最大轮数后停止工具循环。
- `deepseek-reasoner + 联网`：直接使用 Tool Calls；同一用户回合的工具子请求保留 `reasoning_content`，下一用户回合前清理历史 `reasoning_content`。
- `web_search` schema 按 strict 兼容风格书写，但第一版不默认使用 `https://api.deepseek.com/beta`。
- 搜索结果来源挂到 assistant message。
- 搜索失败时生成失败 tool message，不中断 transcript。
- 主消息流只显示轻提示，不展示搜索卡片。

详细设计见 `web-search-design.md`。

## DeepSeek SSE 解析规则

- 使用 `requestInStream`。
- 监听 `dataReceive`。
- 使用 `TextDecoder('utf-8')`。
- 按空行切分 SSE event。
- 只处理 `data: ` 行。
- `[DONE]` 触发 complete。
- `delta.content` 追加到正文。
- `delta.reasoning_content` 追加到 reasoning。
- `stream_options.include_usage = true`。
- JSON 解析失败不要崩溃，应忽略当前不完整 event。
- 忽略服务端高峰期可能发送的空行和 `: keep-alive`。
- 每个 chunk 中的 `id`、`created`、`model`、`system_fingerprint` 应写入 assistant 消息元数据。
- usage chunk 中的 token 和 cache 字段应持久化。

更详细的 DeepSeek API 约束见 `deepseek-api-notes.md`。特别注意：`deepseek-reasoner` 的 `reasoning_content` 在普通下一轮历史中必须移除，但在同一用户回合的工具子请求中必须保留。

## DeepSeek 错误处理

DeepSeek 错误应映射成用户可读文案：

- 401：API Key 无效，请检查密钥。
- 402 / 余额不足：余额不足或账户不可用。
- 429：请求过于频繁，请稍后重试。
- 5xx：DeepSeek 服务异常。
- 网络超时：网络请求超时，请稍后重试。
- 用户取消：不要显示成错误。
- finish_reason = length：提示回复达到长度限制。
- finish_reason = tool_calls：仅在联网搜索开启时执行内置 web_search；否则标记异常。

## ChatViewModel

### 状态

```ts
class ChatViewModel {
  conversations: Conversation[]
  currentConversation: Conversation | null
  inputText: string
  isLoading: boolean
  errorMessage: string
  modelMode: ModelMode
}
```

### 行为

- `init()`
- `createNewConversation()`
- `switchConversation(id)`
- `deleteConversation(id)`
- `sendMessage()`
- `stopGenerating()`
- `retryLastMessage()`
- `deleteMessage(id)`
- `renameConversation(id, title)`

## 上下文构造

第一版不要做复杂 ContextRuntime。

只需要：

- 当前会话最近 N 条消息。
- 如果超长，保留最近消息，前面做简单摘要或截断。
- 不要自动搜索历史会话。
- 不要自动注入工具说明。
- 不要引入与聊天无关的额外系统提示。
- 不要在每轮请求中注入随机时间戳、调试 ID 或动态系统文本，这会破坏 DeepSeek 上下文缓存的重复前缀。
- reasoner 普通历史拼接要清理上一回合的 `reasoning_content`；reasoner 工具子请求不要清理当前回合的 `reasoning_content`。

建议：

```ts
const MAX_RECENT_MESSAGES = 24
const MAX_MESSAGE_CHARS = 12000
```

## 附件策略

第一版附件只进入输入框或内部附件上下文，不要进入工具循环。

- OCR：识别文本后追加到输入框，用户自己决定发送。
- 分享文本：填入输入框。
- 分享链接：填入输入框。

## 日志

使用轻量 `RuntimeHiLog`：

应该记录：

- app init。
- conversation loaded。
- message send started。
- stream started。
- stream canceled。
- stream completed。
- stream failed。
- message persisted。
- response metadata received。
- balance checked。
- models checked。
- service status opened。
- web search started。
- web search completed。
- web search failed。
- web search tool called。
- web search tool rejected。

不记录：

- API Key。
- 完整 prompt。
- 完整用户消息。
- 完整模型回复。
- 附件正文。
- 具体余额数值。

设置页可以提供 DeepSeek Platform、API 服务状态、账单/用量页面的外部链接，但不要在 App 内复刻充值、发票、退款和分 Key 财务报表。

## 测试优先级

必须有测试：

- SSE 解析。
- 会话增量保存。
- 删除消息不恢复。
- 删除会话不恢复。
- 错误码映射。
- finish_reason 映射。
- usage / cache token 解析。
- `/models` 响应解析。
- `/user/balance` 响应解析。
- 搜索结果解析和去重。
- `finish_reason=tool_calls` 工具轮。
- tool arguments JSON parse 失败。
- 未授权工具名拒绝执行。
- 搜索失败生成失败 tool message。
- reasoner 工具子请求保留 `reasoning_content`。
- 下一用户回合前清理历史 `reasoning_content`。
- 删除消息同步删除 tool calls 和搜索来源。
- Markdown 基础渲染逻辑。

## Commit 习惯

工程从第一天保持清晰提交：

- `chore: initialize harmonyos app`
- `feat: add deepseek streaming client`
- `feat: add conversation persistence`
- `feat: add chat shell`
- `feat: add markdown renderer`
- `feat: add api key settings`
- `test: cover conversation persistence`

不要提交“方向调整”“临时实验”“大杂烩工具”。
