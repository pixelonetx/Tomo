# DeepSeek API 要点

本文记录应用接入 DeepSeek API 时必须遵守的事实，以及服务器返回中应该被 App 消化利用的字段。

资料来源以 DeepSeek 中文官方文档为准：

- https://api-docs.deepseek.com/zh-cn/
- https://api-docs.deepseek.com/zh-cn/api/create-chat-completion
- https://api-docs.deepseek.com/zh-cn/api/list-models
- https://api-docs.deepseek.com/zh-cn/api/get-user-balance
- https://api-docs.deepseek.com/zh-cn/guides/thinking_mode
- https://api-docs.deepseek.com/zh-cn/guides/tool_calls
- https://api-docs.deepseek.com/zh-cn/guides/multi_round_chat
- https://api-docs.deepseek.com/zh-cn/guides/kv_cache
- https://api-docs.deepseek.com/zh-cn/guides/json_mode
- https://api-docs.deepseek.com/zh-cn/quick_start/pricing
- https://api-docs.deepseek.com/zh-cn/quick_start/parameter_settings
- https://api-docs.deepseek.com/zh-cn/quick_start/token_usage
- https://api-docs.deepseek.com/zh-cn/quick_start/rate_limit
- https://api-docs.deepseek.com/zh-cn/quick_start/error_codes
- https://api-docs.deepseek.com/zh-cn/news/news251201

## 结论

目标应用是 DeepSeek Chat Client。主链路只接：

- `/chat/completions`
- `/models`
- `/user/balance`

服务器返回里应该用上的信息：

- `choices[].message.content`：最终回答。
- `choices[].message.reasoning_content`：Reasoner 思考内容。普通下一轮历史不发回；同一用户回合的工具子请求必须发回。
- `choices[].finish_reason`：判断是否正常结束、被截断或异常。
- `id`：响应 ID，用于诊断。
- `created`：响应创建时间。
- `model`：实际使用模型。
- `system_fingerprint`：后端配置指纹，存在时保存到消息元数据。
- `usage.prompt_tokens`：输入 token。
- `usage.completion_tokens`：输出 token。
- `usage.total_tokens`：总 token。
- `usage.completion_tokens_details.reasoning_tokens`：Reasoner 思考 token。
- `usage.prompt_cache_hit_tokens`：命中上下文缓存的输入 token。
- `usage.prompt_cache_miss_tokens`：未命中上下文缓存的输入 token。
- `choices[].message.tool_calls`：模型请求调用工具，联网搜索使用这个协议。
- `/models` 返回的模型列表：设置页诊断模型可用性。
- `/user/balance` 返回的余额状态：用户手动查询，不自动刷屏。

不进入主线：

- FIM Completion。
- Chat Prefix Completion Beta。
- Anthropic API 兼容层。
- JSON Output 的 UI 功能。

Tool Calls 只用于内置 `web_search`，不扩展成任意工具执行平台。

JSON Output 可作为内部测试或未来结构化摘要的实现细节，但第一版不要暴露给用户，也不要把普通聊天改成 JSON 模式。

## 基础配置

```text
base_url = https://api.deepseek.com
chat_endpoint = /chat/completions
models_endpoint = /models
balance_endpoint = /user/balance
```

DeepSeek API 兼容 OpenAI Chat Completions 格式。

也可以使用 `https://api.deepseek.com/v1` 作为 OpenAI SDK 兼容 base URL，但这里的 `v1` 和模型版本无关。应用直接使用 `https://api.deepseek.com` 即可。

## 模型

应用只需要支持两个模型模式：

```text
deepseek-chat
deepseek-reasoner
```

官方当前说明：

- `deepseek-chat` 是 DeepSeek-V3.2 非思考模式。
- `deepseek-reasoner` 是 DeepSeek-V3.2 思考模式。
- 两者上下文长度都是 128K。
- `deepseek-chat` 默认最大输出 4K，最大 8K。
- `deepseek-reasoner` 默认最大输出 32K，最大 64K。
- 两者都支持 JSON Output、Tool Calls、对话前缀续写。
- FIM 补全只支持 `deepseek-chat`，不支持 `deepseek-reasoner`，本项目第一版不做 FIM。

思考模式有两种开启方式：

```json
{ "model": "deepseek-reasoner" }
```

或：

```json
{
  "model": "deepseek-chat",
  "thinking": { "type": "enabled" }
}
```

第一版优先使用 `deepseek-reasoner`，因为它语义清楚，也便于设置页直接展示 Chat / Reasoner 两种模式。

设置页应该提供“检查模型可用性”：

```http
GET /models
Authorization: Bearer <API_KEY>
```

响应结构：

```json
{
  "object": "list",
  "data": [
    {
      "id": "deepseek-chat",
      "object": "model",
      "owned_by": "deepseek"
    },
    {
      "id": "deepseek-reasoner",
      "object": "model",
      "owned_by": "deepseek"
    }
  ]
}
```

App 使用方式：

- 首次保存 API Key 后可以静默检查一次模型列表。
- 设置页可手动刷新模型列表。
- 如果 `deepseek-chat` 或 `deepseek-reasoner` 缺失，显示轻量提示。
- 不要把模型列表作为聊天消息展示。

## 非流式请求

最小请求：

```json
{
  "model": "deepseek-chat",
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user", "content": "Hello!" }
  ],
  "stream": false
}
```

请求头：

```text
Content-Type: application/json
Authorization: Bearer <API_KEY>
```

非流式可用于连通性测试，不作为主聊天体验。

## 流式请求

应用默认应使用流式请求：

```json
{
  "model": "deepseek-chat",
  "messages": [
    { "role": "user", "content": "Hello!" }
  ],
  "stream": true,
  "stream_options": {
    "include_usage": true
  }
}
```

流式响应是 SSE：

- 每个事件以 `data: ` 开头。
- 结束事件是 `data: [DONE]`。
- `delta.content` 是普通回答增量。
- `delta.reasoning_content` 是 reasoner 的思考内容增量。
- `stream_options.include_usage = true` 时，结束前会额外返回 usage chunk。
- 高峰期服务端可能发送空行或 `: keep-alive`，解析器必须忽略。

## 响应元数据

非流式响应包含：

```json
{
  "id": "930c60df-bf64-41c9-a88e-3ec75f81e00e",
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "Hello! How can I help you today?",
        "role": "assistant"
      }
    }
  ],
  "created": 1705651092,
  "model": "deepseek-chat",
  "object": "chat.completion",
  "usage": {
    "completion_tokens": 10,
    "prompt_tokens": 16,
    "total_tokens": 26
  }
}
```

流式 chunk 也会带 `id`、`created`、`model`、`system_fingerprint` 等字段。App 应保存到 assistant 消息元数据：

```ts
export interface MessageApiMetadata {
  responseId: string
  model: string
  created: number
  systemFingerprint: string
  finishReason: string
}
```

使用方式：

- 主消息流不展示这些字段。
- 消息长按菜单里的“详情”可以展示模型、token、结束原因。
- 日志只记录 responseId、model、finishReason、token 数，不记录正文。

## finish_reason

必须保存 `finish_reason`，并按状态处理：

| finish_reason | 处理 |
| --- | --- |
| `stop` | 正常完成，不额外提示。 |
| `length` | 回复被截断，消息底部显示“回复达到长度限制，可继续追问或增大输出长度”。 |
| `tool_calls` | 如果联网搜索开启，执行受控 `web_search` 工具轮；否则标记为异常并提示。 |
| `content_filter` | 内容被过滤，显示合适提示。 |
| `insufficient_system_resource` | 服务端推理资源不足，提示稍后重试。 |
| 其他未知值 | 保存原始值，显示通用异常提示。 |

## Function Calling / Tool Calls

联网搜索应使用 DeepSeek Function Calling。

请求侧：

- `tools` 定义可调用工具。
- `tool_choice` 控制工具调用策略。
- `tool_choice=auto` 表示模型可以回答，也可以调用工具。
- `tool_choice=none` 表示禁用工具，只生成回答。
- `tool_choice=required` 表示必须调用工具。

响应侧：

- `finish_reason=tool_calls` 表示模型请求调用工具。
- `choices[].message.tool_calls[]` 包含工具名和 arguments。
- 工具 arguments 是 JSON 字符串，但官方提醒模型不一定生成合法 JSON，App 必须校验。
- App 执行工具后，必须追加 `role=tool`、`tool_call_id=<id>`、`content=<tool result>` 的消息，再继续请求模型。

第一版只定义一个工具：

```text
web_search
```

不要开放任意工具，不要做工具市场，不要提供用户自定义工具 schema。

### strict 模式

DeepSeek Tool Calls 提供 `strict` 模式 Beta：

- 需要使用 `base_url="https://api.deepseek.com/beta"`。
- tool 的 `function.strict` 设为 `true`。
- 所有 object 属性都需要在 `required` 中列出。
- object 必须设置 `additionalProperties: false`。
- 支持的 JSON Schema 类型包括 object、string、number、integer、boolean、array、enum、anyOf。

第一版不默认使用 strict 模式，原因：

- 它是 Beta。
- 需要切换 beta base URL。
- 普通模式加本地参数校验已经足够支撑一个内置 `web_search`。

但 `web_search` schema 应按 strict 兼容风格书写，方便以后切换。

### Reasoner 与工具

DeepSeek-V3.2 已支持思考模式下的工具调用。

- `deepseek-chat + 联网`：直接使用 Tool Calls。
- `deepseek-reasoner + 联网`：也直接使用 Tool Calls。
- 同一用户回合内，reasoner 工具子请求必须回传本回合 assistant 消息里的 `reasoning_content`，让模型继续之前的思考。
- 下一个用户回合开始前，清理之前回合中的 `reasoning_content`，只保留最终回答和必要工具 transcript。
- `DeepSeek-V3.2-Speciale` 临时 API 不支持工具调用，不纳入本项目第一版。

## Reasoner 特殊规则

`deepseek-reasoner` 会返回：

- `reasoning_content`：思考内容。
- `content`：最终回答。

普通多轮对话时必须注意：

```text
不要把上一轮已完成回合的 assistant reasoning_content 再发回 API。
```

但在思考模式工具调用过程中，同一用户回合的子请求需要回传该回合产生的 `reasoning_content`。如果没有正确回传，API 可能返回 400。

因此应用需要区分两种拼接：

### 普通下一轮历史

```json
{ "role": "assistant", "content": "<final answer>" }
```

不要发送上一回合的：

```json
{
  "role": "assistant",
  "content": "<final answer>",
  "reasoning_content": "<reasoning>"
}
```

### 同一回合工具子请求

需要保留本回合 assistant message 的：

```json
{
  "role": "assistant",
  "content": "",
  "reasoning_content": "<reasoning for this sub-turn>",
  "tool_calls": [...]
}
```

然后追加：

```json
{
  "role": "tool",
  "tool_call_id": "<tool_call_id>",
  "content": "<tool result>"
}
```

UI 策略：

- Reasoning 默认折叠。
- 只展示给用户主动展开。
- 复制回复默认只复制最终 `content`。
- 复制 reasoning 需要单独入口。

## 参数策略

### deepseek-chat

推荐默认：

```json
{
  "temperature": 1.0,
  "max_tokens": 4096
}
```

官方温度建议：

| 场景 | temperature |
| --- | --- |
| Coding / Math | `0.0` |
| Data Cleaning / Data Analysis | `1.0` |
| General Conversation | `1.3` |
| Translation | `1.3` |
| Creative Writing / Poetry | `1.5` |

第一版不要把这些做成复杂预设。可以只保留一个“高级设置”里的温度滑块，默认不展开。

### deepseek-reasoner

官方说明 reasoner 不支持这些参数：

- `temperature`
- `top_p`
- `presence_penalty`
- `frequency_penalty`
- `logprobs`
- `top_logprobs`

其中部分参数传了也不会报错，但不会生效。应用应该直接不要传。

Reasoner 可以传：

```json
{
  "max_tokens": 32768
}
```

第一版建议给 reasoner 设置较保守的最大输出，例如 8192 或 16384，避免移动端长时间输出影响体验。

如果使用 `model=deepseek-chat` 搭配 `thinking: { type: 'enabled' }`，也应按 reasoner 参数规则处理，不要传上述不支持参数。

## Token 和 usage

usage 里可能包含：

```json
{
  "prompt_tokens": 14,
  "completion_tokens": 22,
  "total_tokens": 36,
  "completion_tokens_details": {
    "reasoning_tokens": 20
  },
  "prompt_cache_hit_tokens": 0,
  "prompt_cache_miss_tokens": 14
}
```

App 应该保存：

```ts
export interface UsageInfo {
  promptTokens: number
  completionTokens: number
  totalTokens: number
  reasoningTokens: number
  cacheHitTokens: number
  cacheMissTokens: number
}
```

使用方式：

- 消息详情展示本次请求 token。
- 设置页展示“今日/本会话 token 粗略统计”可以作为第二版。
- 不要在消息正文下面常驻显示 token，以免污染聊天体验。
- 费用估算可以后做，因为价格会变化，且余额接口更可靠。

## 上下文缓存

DeepSeek Context Caching 默认启用，不需要客户端开关。

它依赖重复前缀命中缓存，因此 App 应避免无意义改变历史消息格式：

- 不要在每轮请求里加入随机 ID、时间戳、调试文本。
- system prompt 保持稳定。
- 发送历史消息时字段顺序和内容尽量稳定。
- Reasoner 历史只发最终 `content`，不发 reasoning。

DeepSeek 会在 usage 里返回：

- `prompt_cache_hit_tokens`
- `prompt_cache_miss_tokens`

App 只需要保存并在消息详情/诊断中展示。不要自己实现缓存系统。

中文价格页显示当前 V3.2 价格为：

- 输入缓存命中：0.2 元 / 百万 tokens。
- 输入缓存未命中：2 元 / 百万 tokens。
- 输出：3 元 / 百万 tokens。

价格可能调整，App 不应把价格硬编码为业务逻辑。若做费用估算，应在设置页标注“按文档当前价格估算，仅供参考”，并优先提供余额查询。

## 余额查询

设置页提供手动余额查询：

```http
GET /user/balance
Authorization: Bearer <API_KEY>
```

响应结构：

```json
{
  "is_available": true,
  "balance_infos": [
    {
      "currency": "CNY",
      "total_balance": "110.00",
      "granted_balance": "10.00",
      "topped_up_balance": "100.00"
    }
  ]
}
```

App 使用方式：

- 只在用户点击“查询余额”时调用。
- 设置页展示 `is_available`、币种、总余额、赠余额、充值余额。
- 不把余额写进聊天消息。
- 不在日志里记录具体余额数值。
- 可以记录“balance_checked success/failure”。

## JSON Output

官方 JSON Output 通过：

```json
{
  "response_format": {
    "type": "json_object"
  }
}
```

并要求 system 或 user prompt 里包含 `json`，同时提供目标 JSON 示例。

第一版不把 JSON Output 做成用户功能，原因：

- 普通聊天不需要。
- JSON 模式偶尔可能返回空内容。
- 如果提示词没写好，可能长时间输出空白直到长度限制。

可保留为未来内部能力：

- 自动生成会话标题。
- 将长文本压缩成结构化摘要。
- 导入导出时校验结构。

如果未来使用，必须设置合理 `max_tokens`，并对空内容、截断 JSON 做失败处理。

## 错误码映射

官方错误码：

| HTTP code | 含义 | UI 文案建议 |
| --- | --- | --- |
| 400 | Invalid Format | 请求格式错误，请稍后重试或更新应用。 |
| 401 | Authentication Fails | API Key 无效，请检查密钥。 |
| 402 | Insufficient Balance | 余额不足，请检查 DeepSeek 账户余额。 |
| 422 | Invalid Parameters | 请求参数无效，请稍后重试或更新应用。 |
| 429 | Rate Limit Reached | 请求过于频繁，请稍后再试。 |
| 500 | Server Error | DeepSeek 服务异常，请稍后重试。 |
| 503 | Server Overloaded | DeepSeek 服务繁忙，请稍后重试。 |

Rate limit 文档还说明：DeepSeek 不主动限制用户请求频率，但高峰期可能延迟，并发送空行或 keep-alive。App 应该：

- SSE 解析忽略 keep-alive。
- 非流式响应也可能在等待调度时返回空行；如果实现非流式连通性测试，也要容忍空行。
- 给用户保留“停止生成”。
- 超时文案要说“服务响应较慢”，不要误判为 App 崩溃。
- 如果 10 分钟仍无推理开始，服务端可能断开连接，App 应给出重试入口。

FAQ 还说明当前没有按用户设置固定并发上限，也暂不支持为单个账号提高并发上限；高负载时可能由动态限流触发 429 或 503。因此 App 不应承诺“高并发模式”，只应做好排队、重试和清晰提示。

## 平台能力边界

从 FAQ 和 API 指南看，以下能力不应塞进聊天主线：

- 充值、退款、发票、实名认证：跳转 DeepSeek Platform，不在 App 内复刻。
- 分 API Key 用量明细：平台可导出 CSV；App 只做本地粗略 usage 统计。
- Anthropic API：用于其它客户端兼容场景，不适合第一版。
- 实用集成仓库：可作为未来参考，不作为第一版依赖。

## 本地连通性验证

使用临时密钥做过最小验证，密钥未写入文档和文件。

### 非流式 chat

请求：

```text
model = deepseek-chat
stream = false
prompt = Reply with exactly: DEEPSEEK_CHAT_OK
```

结果：

```json
{
  "ok": true,
  "model": "deepseek-chat",
  "finish_reason": "stop",
  "content": "DEEPSEEK_CHAT_OK",
  "total_tokens": 20
}
```

### 流式 reasoner

请求：

```text
model = deepseek-reasoner
stream = true
stream_options.include_usage = true
prompt = What is 1+1? Answer briefly.
```

结果：

```json
{
  "ok": true,
  "finish_reason": "stop",
  "content": "2",
  "reasoning_chars": 58,
  "total_tokens": 36,
  "reasoning_tokens": 20,
  "cache_hit_tokens": 0,
  "cache_miss_tokens": 14
}
```

### 模型列表和余额

请求：

```text
GET /models
GET /user/balance
```

结果：

```json
{
  "models": ["deepseek-chat", "deepseek-reasoner"],
  "balance_shape": {
    "is_available": true,
    "currency_count": 1,
    "currencies": ["CNY"],
    "has_total_balance": true,
    "has_granted_balance": true,
    "has_topped_up_balance": true
  }
}
```

只验证结构，不把具体余额写入文档。

## ArkTS 实现建议

### 常量

```ts
export class ApiConstants {
  static readonly BASE_URL: string = 'https://api.deepseek.com'
  static readonly CHAT_ENDPOINT: string = '/chat/completions'
  static readonly MODELS_ENDPOINT: string = '/models'
  static readonly BALANCE_ENDPOINT: string = '/user/balance'
  static readonly MODEL_CHAT: string = 'deepseek-chat'
  static readonly MODEL_REASONER: string = 'deepseek-reasoner'
  static readonly THINKING_ENABLED: string = 'enabled'
  static readonly THINKING_DISABLED: string = 'disabled'
  static readonly STREAM_DONE_SIGNAL: string = '[DONE]'
  static readonly SSE_DATA_PREFIX: string = 'data: '
  static readonly REQUEST_TIMEOUT: number = 60000
  static readonly CHAT_DEFAULT_MAX_TOKENS: number = 4096
  static readonly REASONER_DEFAULT_MAX_TOKENS: number = 8192
}
```

### 构造请求

```ts
private buildRequestBody(messages: ApiMessage[], mode: ModelMode): ChatCompletionRequest {
  if (mode === ModelMode.REASONER) {
    return {
      model: ApiConstants.MODEL_REASONER,
      messages: this.stripReasoningFromHistory(messages),
      stream: true,
      stream_options: { include_usage: true },
      max_tokens: ApiConstants.REASONER_DEFAULT_MAX_TOKENS
    }
  }

  return {
    model: ApiConstants.MODEL_CHAT,
    messages,
    stream: true,
    stream_options: { include_usage: true },
    temperature: 1.0,
    max_tokens: ApiConstants.CHAT_DEFAULT_MAX_TOKENS
  }
}
```

如果使用 `deepseek-chat` 加 `thinking` 打开思考模式，请在 body 中加入：

```json
{
  "thinking": { "type": "enabled" }
}
```

### stripReasoningFromHistory

```ts
private stripReasoningFromHistory(messages: ApiMessage[]): ApiMessage[] {
  return messages.map((item: ApiMessage): ApiMessage => {
    return {
      role: item.role,
      content: item.content
    }
  })
}
```

这个方法只用于新用户回合开始前的历史拼接。不要在 reasoner 同一工具回合内部调用它，否则会破坏思考模式工具调用。

### SSE 解析

实现要点：

- 用 `TextDecoder('utf-8')`。
- 缓存未完成文本。
- 按 `\n\n` 或空行切分完整 SSE event。
- 忽略 keep-alive、以 `:` 开头的注释行和空行。
- 只解析 `data: ` 行。
- JSON parse 失败不要崩溃。
- `[DONE]` 后触发 complete。
- complete 前如果有 usage chunk，要更新 usage。
- reasoner 中 `reasoning_content` 和 `content` 可能分别出现在不同 chunk，两个缓冲区都要维护。

### DeepSeekService 接口

```ts
export class DeepSeekService {
  setApiKey(key: string): void
  cancelRequest(): void
  sendStreamChat(messages: ApiMessage[], mode: ModelMode, callback: StreamCallback): Promise<void>
  sendToolRound(messages: ApiMessage[], tools: ApiToolDefinition[]): Promise<ChatCompletionResponse | null>
  sendChat(messages: ApiMessage[], mode: ModelMode): Promise<ChatCompletionResponse | null>
  fetchModels(): Promise<ModelListResponse | null>
  fetchBalance(): Promise<BalanceResponse | null>
}
```

## 安全要求

- API Key 只存安全存储或首选项加密方案。
- 不在日志里打印 API Key。
- 不在文档里写 API Key。
- 不在错误信息里包含 Authorization header。
- 不在日志里打印完整 prompt、完整回复和具体余额。
- 用户清除数据时必须清除 API Key 和会话数据。
