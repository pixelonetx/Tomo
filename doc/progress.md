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

### 验证

- `D:\dev\Huawei\command-line-tools\bin\hvigorw.bat assembleHap --no-daemon`
  - 输出 `BUILD SUCCESSFUL`。
- `D:\dev\Huawei\command-line-tools\bin\hvigorw.bat test --no-daemon`
  - 通过，输出 `BUILD SUCCESSFUL`。
- `D:\dev\Huawei\command-line-tools\bin\codelinter.bat .`
  - 输出 `No defects found in your code.`。
  - 返回 exit code 1，符合 `implementation-prompt.md` 中记录的当前工具行为。

### 下一步

1. 实现 API Key 设置页，并说明本地保存边界和风险。
2. 实现 `ConversationRdbService` 和 `ConversationService`，接入增量保存。
3. 将 `ChatViewModel` 的内存会话替换为服务层持久化会话。
