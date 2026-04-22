# 实现进展

## 2026-04-22

### 已完成

- 将模板首页替换为轻量 DeepSeek Chat 首页壳：
  - 顶部渐变遮罩。
  - 底部渐变遮罩。
  - 胶囊输入栏。
  - 联网搜索开关。
  - 新建会话、切换会话和侧边栏基础交互。
  - Assistant 无卡片、User 右侧气泡的消息流方向。
- 新增第一批核心模型：
  - `ApiModels.ets`
  - `ChatModels.ets`
  - `SettingsModels.ets`
  - `SearchModels.ets`
- 新增 DeepSeek SSE 纯解析模块：
  - 解析 `delta.content`。
  - 解析 `delta.reasoning_content`。
  - 解析 `[DONE]`。
  - 解析 usage、reasoning tokens 和 prompt cache tokens。
  - 映射常见 DeepSeek HTTP 错误。
- 按 UI 文档补齐基础深浅色资源和字号资源。
- 新增本地单元测试覆盖：
  - 模型模式到 DeepSeek model id 映射。
  - 会话标题裁剪。
  - 消息模型创建。
  - SSE content / reasoning / usage / `[DONE]` 解析。
  - 搜索结果 URL 去重和最多 5 条限制。
  - DeepSeek 错误码映射。
- 新增 `PreferencesService`：
  - 使用 HarmonyOS Preferences 保存轻量用户设置。
  - 集中定义 Preferences key。
  - 支持冷启动默认值恢复。
  - 支持保存、重置设置、标记 API Key / 搜索 API Key 配置状态。
  - 写入后统一 `flush`。
  - 将搜索结果数量限制在 1 到 5。
- 新增默认设置测试，覆盖模型、字号、背景、联网搜索默认值。
- 新增 `DeepSeekService`：
  - 支持设置 API Key。
  - 支持取消当前流式请求并释放 `HttpRequest`。
  - 使用 `requestInStream` 接入 `/chat/completions`。
  - 请求体按 Chat / Reasoner 分支构造，Reasoner 历史默认移除 `reasoning_content`。
  - 流式数据进入 SSE 解析器并回调 content、reasoning、metadata 和 usage。
  - 支持 `/models` 和 `/user/balance` 的文本请求与响应结构解析。
  - 为应用声明 `ohos.permission.INTERNET`。
- 新增 DeepSeek 请求体、模型列表和余额响应解析测试。
- 新增 `ChatViewModel`：
  - 从首页抽离会话、消息、输入、发送、停止、重试和联网开关状态。
  - 初始化时读取 `PreferencesService` 并应用模型模式、字号、背景和联网搜索默认值。
  - 发送消息时接入 `DeepSeekService.sendStreamChat()`。
  - 流式回调增量更新 assistant content、reasoning、metadata 和 usage。
  - API Key 未配置时保留用户消息，并将 assistant 标记为失败状态。
  - 重试会删除上一条 assistant 和对应 user 后重新发送，避免重复脏消息。
- 首页 `Index.ets` 改为展示层，只绑定 `ChatViewModel` 状态并转发交互。
- `DeepSeekService` 的 HTTP 流式请求改为官方 `requestInStream().then().catch()` 写法，并补齐 `expectDataType`、`usingCache`、`priority`、`usingProtocol` 和完整事件销毁。
- `PreferencesService` 补充同步 Preferences API 的异常处理，避免 ArkTS 编译警告。
- 新增 API Key 设置 sheet：
  - 侧边栏入口显示 API Key 配置状态。
  - 支持输入、保存和清除 DeepSeek API Key。
  - 保存后注入 `ChatViewModel.setApiKey()`，聊天发送可直接使用真实流式请求。
  - 支持通过 `/models` 检查 API Key 连通性，并确认 `deepseek-chat` / `deepseek-reasoner` 可用。
  - 页面明确提示第一版 API Key 保存在应用沙箱 Preferences，后续迁移系统安全存储。
- `PreferencesService` 临时支持保存、读取和清除 API Key，并同步维护 `apiKeyConfigured`。
- 新增 `ConversationRdbService`：
  - 创建 `conversations`、`messages`、`message_tool_calls`、`message_search_sources` 表。
  - 创建 `idx_messages_conversation_time` 索引。
  - 支持会话 insert / rename / delete。
  - 支持消息 insert-or-replace / update / delete。
  - 删除会话时同步删除消息、tool calls 和搜索来源。
  - 删除消息时同步删除 tool calls 和搜索来源。
  - 支持加载会话及其消息、搜索来源、tool calls。
- 新增 `ConversationService` 作为 ViewModel 与 RDB 的服务边界。
- `ChatViewModel` 接入增量持久化：
  - 启动时初始化 RDB 并加载历史会话。
  - 无历史会话时创建新会话并落库。
  - 新建、删除、重命名会话同步持久化。
  - 发送消息时插入 user / assistant 消息。
  - 流式输出期间节流保存 assistant 消息。
  - 完成、失败、停止生成时强制保存最终 assistant 状态。
  - 删除消息和重试消息同步删除数据库记录，避免脏消息恢复。
- 新增消息操作和详情入口：
  - 每条消息支持复制正文。
  - 每条消息支持打开详情 sheet。
  - 详情展示 role、status、model、finish reason、response id、prompt / completion / reasoning / total tokens、cache hit / miss。
  - 详情 sheet 支持复制消息正文和复制完整 metadata。
  - 复制操作接入系统剪贴板，并使用 UIContext toast 提示结果。
- 收敛 `ConversationRdbService` RDB API 编译警告：
  - `execute` 调用统一走 `executeSql()`，同步抛错和 Promise 失败统一包装。
  - `querySql` 调用显式放入 `try/catch/finally`，确保 `ResultSet` 始终关闭。
  - `goToNextRow`、`getString`、`getLong`、`close` 等可能抛异常点均进入明确异常边界。
  - `assembleHap` 不再输出 `ConversationRdbService` 的 `Function may throw exceptions` 警告。
- 将 Markdown / 代码块渲染从轻量 demo 升级为本地成熟渲染链路：
  - 移除自研简易 `MarkdownParser`。
  - 引入本地 rawfile 运行时资产 `markdown-it@14.1.1` 和 `katex@0.16.45`，并补充 MIT license 文本。
  - 使用 ArkWeb 本地 `loadData()` 渲染 Assistant 正文，用户消息继续保持右侧气泡纯文本。
  - Markdown 支持标题、段落、强调、引用、列表、分隔线、表格、自动链接、图片、代码块等 markdown-it 能力。
  - 数学公式支持 `$...$`、`$$...$$`、`\(...\)`、`\[...\]`，由 KaTeX auto-render 渲染。
  - 代码块支持语言标签、横向滚动和 Web 内复制按钮。
  - HTML 拼装禁用 Markdown 原始 HTML，链接统一 `target="_blank"` / `rel="noopener noreferrer"`，脚本数据做 `</script>` 防截断处理。
  - 新增本地单元测试覆盖 HTML shell、KaTeX/markdown-it 资产引用、任务列表归一化和脚本数据保护。
- 新增关于与开源声明入口：
  - 侧边栏新增 `About & licenses`。
  - 关于 sheet 展示应用说明和第三方运行时资产清单。
  - 声明 `markdown-it@14.1.1` / `KaTeX@0.16.45` 的用途、版本、许可证和官网。
  - 展示本地 license 文件位置。
  - 支持复制完整 open source notices。
- 优化 Markdown WebView 高度：
  - `MarkdownMessageView` 增加 `renderedHeight` 状态，首屏使用估算高度兜底。
  - 注册 `markdownBridge.updateMarkdownHeight()` JS proxy，由 Web 页面回传实测高度。
  - Web 端渲染后使用 `scrollHeight` / `offsetHeight` 测量正文高度。
  - 使用 `ResizeObserver`、`MutationObserver`、`load`、`resize` 和多次延迟测量覆盖公式、表格、图片和代码块布局稳定过程。
  - 内容或字号变化时先重置为估算高度，再由实测高度覆盖。
  - 新增单元测试断言高度回传脚本和 bridge 名称存在。
- 新增 Navigation 内置网页查看页：
  - 首页根容器改为 `Navigation + NavPathStack`，保持现有聊天界面作为导航首页。
  - 新增 `WebBrowserDestination`，使用 ArkWeb 加载 http / https 页面。
  - 支持 WebView 内后退，无法后退时弹出 Navigation 子页。
  - 标题跟随网页 `onTitleReceive` 更新，并展示当前 URL 与加载进度。
  - 提供刷新和用系统默认浏览器打开两个操作。
  - Markdown 链接点击通过 `markdownBridge.openLink()` 回传 ArkTS，并推入 Navigation 内置浏览器页。
  - 新增 `BrowserService`，集中处理 URL 归一化和系统浏览器拉起。

### 验证

- `D:\dev\Huawei\command-line-tools\bin\hvigorw.bat assembleHap --no-daemon`
  - 输出 `BUILD SUCCESSFUL`。
  - 无 `ConversationRdbService` RDB API 异常处理警告。
- `D:\dev\Huawei\command-line-tools\bin\hvigorw.bat test --no-daemon`
  - 通过，输出 `BUILD SUCCESSFUL`。
- `D:\dev\Huawei\command-line-tools\bin\codelinter.bat .`
  - 输出 `No defects found in your code.`。
  - 返回 exit code 1，符合 `implementation-prompt.md` 中记录的当前工具行为。

### 下一步

1. 接入联网搜索 Tool Calls 的受控 `web_search` 循环。
2. 继续推进 Reasoning 折叠展示和搜索来源详情。
3. 补齐 Markdown 链接点击的外部浏览器跳转体验。
