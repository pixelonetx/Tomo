# 给新 AI / 开发者的实现指令

你要新建一个 HarmonyOS ArkTS 项目，目标是实现一个干净、稳定、轻量的 DeepSeek Chat Client。

请严格遵守本文档，避免引入与聊天客户端无关的通用编排框架。

## 产品目标

做一个 HarmonyOS 上体验优秀的 DeepSeek 对话应用。

核心能力：

- API Key 设置。
- DeepSeek Chat / Reasoner。
- 联网搜索。
- 流式输出。
- 停止生成。
- 重新生成。
- 会话列表。
- 会话持久化。
- Markdown 和代码块。
- 复制。
- 主题。
- 背景图、渐变透明、玻璃感首页。

## 禁止事项

不要实现与聊天主线无关的功能市场、代码执行、系统级助理能力集合或通用自动化框架。

## 第一步：工程初始化

创建标准 HarmonyOS ArkTS 工程。

ArkUI 组件写法：

- 第一版优先使用成熟的 `@Component`、`@State`、`@Prop`、`@Link` 等常规写法。
- 不要强制全项目使用 `@ComponentV2`。
- 只有在 SDK、DevEco Studio 和实际编译链路确认稳定后，才允许局部使用 `@ComponentV2`。

包名建议：

```text
ai.deepseek.chat
```

应用名：

```text
DeepSeek Chat
```

主页面：

```text
entry/src/main/ets/pages/Index.ets
```

资源：

```text
entry/src/main/resources/base/element/color.json
entry/src/main/resources/dark/element/color.json
entry/src/main/resources/base/element/float.json
```

## 第二步：先做数据模型

实现：

- `ApiModels.ets`
- `ChatModels.ets`
- `SettingsModels.ets`
- `SearchModels.ets`

消息模型保持简单。

消息模型保持简单，只保留对话、状态、reasoning、usage、搜索来源等必要字段。

## 第三步：PreferencesService

实现用户首选项服务。

必须使用 HarmonyOS Preferences 保存轻量设置，不要把用户偏好塞进 RDB。

保存内容：

- 模型模式。
- 主题模式。
- 字号。
- 背景图开关、背景 URI、模糊和透明度。
- 联网搜索默认开关。
- 搜索 provider。
- 搜索结果数量。
- API Key 是否已配置的状态标记。

要求：

- Preferences key 集中定义。
- 冷启动时恢复默认设置。
- 写入后统一 flush。
- 写入失败给轻提示。
- 清空会话不删除用户偏好。
- 重置设置只恢复 Preferences 默认值，不删除聊天记录。

API Key 第一版如果本地保存，必须在设置页说明保存位置和风险；后续优先迁移到系统安全存储。

## 第四步：DeepSeekService

实现纯文本流式对话。

实现前先阅读 `deepseek-api-notes.md`，按其中的官方 API 约束实现。

接口：

```ts
setApiKey(key: string): void
cancelRequest(): void
sendStreamChat(messages: ApiMessage[], mode: ModelMode, callback: StreamCallback): Promise<void>
fetchModels(): Promise<ModelListResponse | null>
fetchBalance(): Promise<BalanceResponse | null>
```

必须支持：

- `deepseek-chat`
- `deepseek-reasoner`
- `thinking: { type: 'enabled' }` 作为思考模式的兼容入口，第一版主路径仍用 `deepseek-reasoner`。
- SSE。
- reasoning_content。
- include_usage。
- finish_reason。
- response id / created / model / system_fingerprint。
- prompt_tokens / completion_tokens / total_tokens。
- reasoning_tokens。
- prompt_cache_hit_tokens / prompt_cache_miss_tokens。
- cancel。
- 错误码映射。
- 多轮 reasoner 请求时移除历史消息里的 `reasoning_content`。
- reasoner 同一用户回合的工具子请求必须保留当前回合 `reasoning_content`。
- `fetchModels()` 用于设置页模型可用性诊断。
- `fetchBalance()` 用于用户手动查询余额。

不要实现通用 tool calling，只允许内置 `web_search`。
不要实现 FIM。
不要把 JSON Output 做成用户可见功能。

## 第五步：SearchService

实现联网搜索，必须使用 DeepSeek Function Calling / Tool Calls 协议，但不要实现任意工具执行平台。

接口：

```ts
setApiKey(key: string): void
search(query: string, options: SearchOptions): Promise<SearchResult[]>
runSearchToolLoop(messages: ApiMessage[], mode: ModelMode): Promise<SearchToolRunResult>
```

必须支持：

- provider 配置。
- 搜索 API Key 配置。
- URL 去重。
- snippet 截断。
- 最多 5 条结果。
- `web_search` tool schema。
- strict 兼容风格 schema：所有属性 required，`additionalProperties: false`。
- `finish_reason=tool_calls` 分支。
- assistant `tool_calls` 解析。
- `role=tool` message 回填。
- 最多 3 轮工具循环。
- reasoner + 联网时直接使用 reasoner Tool Calls。
- reasoner 工具轮内部保留当前回合 `reasoning_content`。
- 下一用户回合前清理上一回合 `reasoning_content`。
- 搜索来源挂到 assistant message 详情。

不要：

- 抓取搜索引擎 HTML。
- 展示搜索卡片。
- 把搜索结果写进用户原始消息。
- 开放任意工具。
- 做任意工具执行平台或用户自定义工具。

## 第六步：会话持久化

实现：

- `ConversationRdbService`
- `ConversationService`

使用 RDB 增量保存。

必须支持：

- insert conversation。
- update conversation title。
- delete conversation。
- insert message。
- update message。
- delete message。
- insert message search sources。
- delete message search sources。
- insert message tool calls。
- delete message tool calls。
- load conversations with messages。

删除消息和删除会话必须真的从数据库删除。

## 第七步：ChatViewModel

实现状态和行为：

```ts
init()
createNewConversation()
switchConversation(id)
deleteConversation(id)
sendMessage()
stopGenerating()
retryLastMessage()
deleteMessage(id)
renameConversation(id, title)
toggleWebSearch()
```

流式输出时：

- 先插入 user message。
- 再插入 assistant message，状态 `SENDING`。
- 每个 chunk 更新内存。
- 每个 chunk 读取并保存响应元数据。
- usage chunk 到达后更新 token 和 cache 字段。
- 节流持久化。
- complete 时写最终内容和状态。
- finish_reason 为 `length` 时保留内容并显示截断提示。
- finish_reason 为 `tool_calls` 时仅在联网搜索开启时执行内置 `web_search`，否则标记为异常。
- error 时写失败状态。
- cancel 时写取消状态或保留已生成内容，策略要明确。
- 如果联网搜索开启，走受控 `web_search` 工具循环。
- 如果模型请求未授权工具，拒绝执行并写失败 tool message。
- 如果工具参数解析失败，写失败 tool message。
- 如果搜索失败，保留用户消息，让模型基于失败 tool message 继续回答，并给轻提示。

## 第八步：UI

主界面必须体现轻盈通透的视觉方向。

结构：

```text
Stack
  BackgroundLayer
  MessageList
  TopGradientOverlay
  BottomGradientOverlay
  ChatInputBar
  SidebarPanel
  ApiKeySheet
```

要求：

- 顶部透明渐变。
- 底部透明渐变。
- 背景、顶部渐变、底部渐变可以使用 `expandSafeArea` 延伸到系统安全区。
- 输入栏、按钮和消息内容必须避让状态栏、导航区域和键盘。
- 不要为了沉浸式粗暴隐藏状态栏或导航区域。
- 可选背景图和模糊。
- 输入栏胶囊形。
- 输入栏有一个轻量“联网”开关。
- Assistant 消息无卡片。
- User 消息右侧气泡。
- Reasoning 默认折叠。
- Markdown 清晰。
- 代码块可复制。
- 搜索来源不做卡片，放到消息详情。

## 第九步：设置页

只做：

- API Key。
- API Key 连通性检查。
- 模型可用性检查。
- 模型模式。
- 联网搜索默认开关。
- 搜索 provider。
- 搜索 API Key。
- 搜索结果数量。
- 主题。
- 字号。
- 背景图。
- 背景模糊。
- 背景透明度。
- 数据管理。
- 余额查询。
- 轻量 usage 统计。
- 关于。

不要做功能市场。
不要把余额和 token 明细放进聊天消息流。
不要把搜索结果做成卡片流。

设置页必须读写 `PreferencesService`，不要直接读写 Preferences。

## 第十步：附件能力

第一版可以先不做。

如果做，只做明确触发：

- 图片 OCR：按钮选择图片，识别后插入输入框。
- 语音输入：按钮开始转写，结果进入输入框。

附件结果不要自动发送，不要刷屏。

## 第十一步：测试

至少测试：

- SSE 解析。
- `[DONE]` complete。
- keep-alive / 空行忽略。
- reasoning_content 解析。
- usage chunk 解析。
- cache token 解析。
- finish_reason 映射。
- reasoner 历史请求不带 reasoning_content。
- reasoner 工具子请求带当前回合 reasoning_content。
- `/models` 响应解析。
- `/user/balance` 响应解析。
- 搜索 provider 响应解析。
- 搜索结果 URL 去重。
- `finish_reason=tool_calls` 分支。
- `web_search` schema 满足 strict 兼容风格。
- assistant `tool_calls` 解析。
- tool arguments JSON parse 失败路径。
- 未授权工具名拒绝执行。
- 多轮搜索达到上限。
- 搜索失败生成失败 tool message。
- 删除消息同步删除 tool calls 和搜索来源。
- 网络错误映射。
- 会话保存。
- 删除消息不恢复。
- 删除会话不恢复。
- retry 不产生脏消息。
- 首次启动读取默认 Preferences。
- 修改主题后重启仍生效。
- 修改字号后消息、Markdown、输入栏同步变化。
- 清空会话不清空用户偏好。
- 重置设置不删除聊天记录。

## 第十二步：验证命令

每次关键改动运行：

```powershell
hvigorw.bat assembleHap --no-daemon
hvigorw.bat test --no-daemon
codelinter.bat .
```

注意：当前环境中 `codelinter.bat .` 可能输出 `No defects found in your code.` 但返回 exit code 1，需要以输出为准记录。

## 完成标准

第一版完成时，用户应该能：

1. 打开 App。
2. 设置 DeepSeek API Key。
3. 新建对话。
4. 选择 Chat 或 Reasoner。
5. 可选择打开联网搜索。
6. 发送问题。
7. 看到流式回复。
8. 停止生成。
9. 重新生成。
10. 复制回复或代码。
11. 关闭 App 再打开，会话仍在。

这十件事做稳，比额外抽象更重要。
