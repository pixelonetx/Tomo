# 联网搜索设计

应用需要支持联网搜索。搜索必须使用 DeepSeek Function Calling 的语义：模型发起 `tool_calls`，App 执行 `web_search`，再把结果作为 `tool` message 返回给模型。

这不是通用自动化平台，也不是伪造上下文。它是一个受控、单工具、有限轮数的搜索运行时。

## 产品形态

主输入栏提供一个轻量开关：

```text
[联网]  今天 DeepSeek API 有什么新变化？
```

触发方式：

- 用户打开“联网”开关后发送。
- 用户明确输入“搜索”“查一下最新”“联网查”等意图时，App 可以在发送前提示或自动启用。
- 默认关闭，不自动搜索。

搜索过程展示：

- 消息流里只显示一行轻状态，例如“正在联网搜索...”。
- 不展示搜索卡片。
- 不展示工具日志。
- 不把原始 JSON 暴露给用户。

回答展示：

- Assistant 正文仍是普通 Markdown。
- 如果答案使用了搜索结果，正文中可以用 `[1]`、`[2]` 这种引用标记。
- 回复底部最多显示一行“来源 3 条”，点击进入消息详情查看标题和链接。
- 不做大卡片，不做网页预览卡片。

## 为什么必须用 Tool Message

把搜索结果直接拼进 user content 有三个问题：

- 语义不真实：搜索结果不是用户说的话。
- 多轮困难：模型无法可靠地区分“上一轮用户文本”和“上一轮工具观察”。
- 调试困难：无法复盘模型何时要求搜索、搜索了什么、工具返回了什么。

正确做法是：

```text
user
assistant(tool_calls: web_search)
tool(tool_call_id: ..., content: search results)
assistant(final answer)
```

## DeepSeek Function Calling 约束

DeepSeek Chat Completion 支持：

- `tools`
- `tool_choice`
- assistant `tool_calls`
- `tool` role message
- `finish_reason = tool_calls`

官方文档也提示：模型生成的 function arguments 不保证一定是合法 JSON，App 调用工具前必须校验参数。

DeepSeek-V3.2 已支持思考模式下的工具调用。因此：

- `deepseek-chat + 联网`：直接走 Function Calling。
- `deepseek-reasoner + 联网`：也直接走 Function Calling，但同一用户回合的工具子请求必须回传该回合产生的 `reasoning_content`，让模型延续思考。
- 下一个用户回合开始前，应清理之前回合的 `reasoning_content`，只保留最终 `content`、必要的 `tool_calls` / `tool` transcript 和普通历史消息。

## 工具定义

第一版只允许一个工具：

```json
{
  "type": "function",
  "function": {
    "name": "web_search",
    "description": "Search the web for current or factual information. Use it when the user asks for latest, current, recent, source-backed, or web-verifiable information.",
    "parameters": {
      "type": "object",
      "properties": {
        "query": {
          "type": "string",
          "description": "The search query."
        },
        "freshness": {
          "type": "string",
          "enum": ["any", "day", "week", "month"],
          "description": "Optional freshness preference."
        }
      },
      "required": ["query", "freshness"],
      "additionalProperties": false
    }
  }
}
```

不开放任意工具，不做工具市场，不做用户自定义工具。

这个 schema 按 DeepSeek strict 模式兼容风格书写：所有属性都在 `required` 中列出，并关闭 `additionalProperties`。第一版仍使用普通 base URL 和本地参数校验，不默认开启 strict Beta。

## 多轮搜索流程

允许模型在一个用户回合内多次搜索，但必须有硬限制。

推荐流程：

```text
1. 用户发送消息，联网开关开启。
2. SearchToolRunner 按当前模式调用 `deepseek-chat` 或 `deepseek-reasoner`，传入 tools=[web_search]，tool_choice=auto。
3. 如果 finish_reason=tool_calls：
   3.1 解析 assistant.tool_calls。
   3.2 校验 function name 只能是 web_search。
   3.3 JSON.parse arguments，失败则生成失败 tool message。
   3.4 执行 SearchService.search()。
   3.5 把搜索结果作为 role=tool、tool_call_id=... 的消息追加到 API transcript。
   3.6 继续下一轮。
4. 如果 finish_reason=stop：
   4.1 得到最终回答。
   4.2 保存 assistant 可见消息和搜索来源。
5. 如果超过 MAX_TOOL_ROUNDS：
   5.1 停止工具循环。
   5.2 要求模型基于已有工具结果总结，或给用户提示搜索轮数已达上限。
```

硬限制：

```ts
const MAX_TOOL_ROUNDS = 3
const MAX_TOOL_CALLS_PER_ROUND = 2
const MAX_SEARCH_RESULTS_PER_CALL = 5
```

这样可以支持“多轮搜索”，但不会变成失控自动化流程。

## Tool Message 内容

Tool message 的 `content` 必须是紧凑 JSON 字符串：

```json
{
  "query": "DeepSeek API latest changes",
  "results": [
    {
      "index": 1,
      "title": "DeepSeek API Docs",
      "url": "https://api-docs.deepseek.com/",
      "snippet": "DeepSeek API documentation...",
      "published_at": "",
      "source": "DeepSeek"
    }
  ]
}
```

要求：

- 最多 5 条结果。
- snippet 截断。
- URL 去重。
- 不放网页全文。
- 不把搜索 API 原始响应完整塞给模型。
- 搜索失败也返回 tool message，例如 `{"error":"search_failed","message":"..."}`，不要中断 transcript。

## SearchService

第一版不要自建爬虫，不要直接抓搜索引擎 HTML。使用标准 Web Search API provider，并通过接口隔离：

```ts
export interface SearchProvider {
  search(query: string, options: SearchOptions): Promise<SearchResult[]>
}
```

可选 provider：

- Brave Search API。
- Bing Web Search API。
- Serper。
- Tavily。
- 其他可替换 provider。

## 数据模型

```ts
export interface SearchOptions {
  maxResults: number
  locale: string
  freshness: 'any' | 'day' | 'week' | 'month'
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

SearchService 返回前必须清洗：

- 去掉空标题。
- 去掉空 URL。
- 去重 URL。
- snippet 过长时截断。
- 最多保留 5 条。
- 不保存网页全文。

## 持久化

消息表不直接塞搜索 JSON。

建议增加两张表。

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

使用方式：

- `message_id` 指向最终 assistant message。
- 用户消息仍只保存用户原文。
- tool transcript 存在内部表，不作为聊天消息展示。
- assistant message 详情页展示来源列表。
- 删除 assistant message 时同步删除 tool calls 和 sources。
- 单条 assistant 消息内的来源编号必须稳定为 1-based citation index。多轮工具调用返回的来源先按 URL 去重，再进入全局来源列表；tool result JSON、Markdown 正文引用 `[n]` 和消息详情来源列表必须使用同一个 index。
- Markdown 渲染层把已知 `[1]`、`[2]` 等 citation 渲染为可点击引用，通过 bridge 回传 citation index，并打开对应来源。

## Reasoner + 搜索

DeepSeek-V3.2 的思考模式支持工具调用。Reasoner 搜索不再绕到 chat 模型，而是直接用 `deepseek-reasoner` 执行工具轮。

关键规则：

- 同一用户回合内，如果 reasoner 返回 `reasoning_content` 和 `tool_calls`，下一次工具子请求必须把这条 assistant message 原样保留在 API transcript 中。
- App 执行工具后追加 `role=tool` message，再继续请求 reasoner。
- 这个过程可能出现多次“思考 + 工具调用”。
- 当同一用户回合完成并进入下一个用户问题时，清理上一回合 assistant 消息里的 `reasoning_content`，以节省带宽并避免历史思维链污染。

单个用户回合：

```text
user
assistant(reasoning_content + tool_calls)
tool(tool_call_id + search result)
assistant(reasoning_content + optional tool_calls)
tool(...)
assistant(reasoning_content + final content)
```

进入下一个用户回合前：

```text
assistant(content + tool_calls, no reasoning_content)
tool(...)
user(new question)
```

注意：工具轮内部需要保留 `reasoning_content`，普通历史拼接时要移除 `reasoning_content`。这两个规则不能混淆。

## 错误处理

搜索失败不能让聊天失败：

- 工具调用参数 JSON 解析失败：追加失败 tool message，让模型解释无法搜索。
- 搜索 provider 失败：追加失败 tool message，让模型基于已有信息回答。
- 超过工具轮数：停止工具循环，提示“搜索轮数已达上限”。
- DeepSeek 可用但搜索不可用：退化为普通聊天，但要在消息详情里记录搜索失败。

常见错误：

- 搜索 API Key 未配置。
- 搜索 provider 网络失败。
- 搜索 provider 限流。
- 搜索结果为空。
- 模型生成了非法工具参数。
- 模型请求了未授权工具。

## 设置页

设置页增加：

- 联网搜索开关默认值。
- 搜索 provider。
- 搜索 API Key。
- 最大搜索结果数，默认 5。
- 地区/语言，默认跟随系统。
- 最大工具轮数，默认 3，不建议用户频繁调整。

不要在第一版做复杂搜索源管理。

## 测试

必须测试：

- `web_search` tool schema。
- `finish_reason=tool_calls` 分支。
- assistant `tool_calls` 解析。
- tool arguments JSON parse 失败路径。
- 未授权工具名拒绝执行。
- 搜索 provider 响应解析。
- URL 去重。
- snippet 截断。
- 多轮搜索达到上限。
- reasoner 工具轮内部保留 `reasoning_content`。
- 下一用户回合前清理历史 `reasoning_content`。
- 搜索失败生成失败 tool message。
- 删除消息时删除 tool calls 和搜索来源。
- 回复引用 `[1]` 时详情页能对应来源。
