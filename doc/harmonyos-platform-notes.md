# HarmonyOS 平台实现要点

本文记录新客户端必须贴合的 HarmonyOS 原生能力。目标不是堆平台 API，而是把聊天客户端做稳、做顺、做得像一个原生应用。

## Preferences

用户首选项必须使用 HarmonyOS Preferences，而不是塞进 RDB 或写自定义 JSON 文件。

适合放入 Preferences：

- `themeMode`：`system` / `light` / `dark`。
- `fontSize`：正文基础字号。
- `backgroundEnabled`、`backgroundImageUri`、`backgroundBlurRadius`、`backgroundOpacity`。
- `modelMode`：`chat` / `reasoner`。
- `webSearchDefaultEnabled`、`searchProvider`、`searchMaxResults`。
- `apiKeyConfigured`、`searchApiKeyConfigured` 这类状态标记。

不适合放入 Preferences：

- 会话列表。
- 消息正文。
- reasoning 内容。
- 搜索来源。
- tool call 记录。
- 大段附件文本。
- 大型 JSON 快照。

安全约束：

- Preferences 官方定位是轻量 Key-Value 存储，适合字体大小、夜间模式等个性化设置。
- 默认 XML 模式需要显式 `flush` 后持久化，写入设置后必须统一落盘。
- 不要在主线程做大数据量同步读写。
- Preferences 不提供加密能力。API Key 如果暂时存入 Preferences，必须在文档和设置页明确这是本地沙箱内保存；更理想的后续方案是接入系统安全存储。
- Key 统一集中定义，禁止页面里散落字符串 key。

推荐服务：

```text
services/
  PreferencesService.ets
```

`PreferencesService` 负责：

- 初始化 Preferences 实例。
- 读取默认设置。
- 更新单项设置。
- 批量恢复设置。
- 写入后统一 flush。
- 对外只暴露类型安全的 `AppSettings`，页面不直接操作 Preferences。

## 会话数据

会话和消息继续使用 RDB。

分工必须清楚：

- Preferences 管用户偏好。
- RDB 管聊天历史。
- 网络层不直接读写 Preferences 或 RDB。
- ViewModel 负责把设置、会话、网络状态组合成 UI 状态。

## 沉浸式

首页视觉要保留渐变透明和背景延伸，但不要粗暴隐藏系统栏。

第一版推荐：

- 使用 `expandSafeArea` 让背景层、顶部渐变、底部渐变延伸到系统安全区。
- 输入栏、按钮、消息内容必须避让状态栏、导航区域和键盘。
- 底部输入栏的可点击区域不能压到导航手势区。
- `setWindowLayoutFullScreen` 只在确有必要时使用，并且所有 window API 都必须捕获异常。
- 不隐藏状态栏和导航区域，除非未来做全屏图片预览。

安全区策略：

- 背景层可以扩展到顶部和底部安全区。
- TopGradientOverlay 可以扩展到顶部安全区。
- BottomGradientOverlay 可以扩展到底部安全区。
- MessageList 和 ChatInputBar 仍按安全区布局。
- 键盘弹出时输入栏跟随键盘避让，不做固定 bottom magic number。

## 深浅色

主题设置提供三档：

- 跟随系统。
- 浅色。
- 深色。

实现要求：

- 颜色优先使用资源文件：`resources/base/element/color.json` 和 `resources/dark/element/color.json`。
- 业务组件不硬编码大面积颜色。
- 背景图开启时，文字、输入栏和渐变遮罩仍要保证可读性。
- 主题选择写入 Preferences，冷启动时恢复。

## 字号

字号是用户首选项，不是单个组件的临时状态。

建议范围：

```text
14 / 15 / 16 / 18 / 20
```

实现要求：

- `fontSize` 写入 Preferences。
- MessageBubble、MarkdownView、CodeBlockView、ChatInputBar 从统一设置读取字号。
- 文本使用可缩放单位，避免大量硬编码。
- 代码块可以比正文小 1 号，但也要跟随整体字号变化。
- 设置页提供恢复默认值。

## 页面与数据

第一版页面少，不需要复杂路由系统。

推荐：

- 主入口 `Index.ets`。
- 设置页可以先用 Sheet 或单独 `SettingsPage.ets`。
- 如果引入页面栈，优先使用 Navigation / NavPathStack。
- 不使用已不推荐的 `@ohos.router` 作为主路径。
- 路由参数只传轻量 ID 或枚举，不传 API Key、消息正文、大型对象。

何时需要 `route_map.json`：

- 第一版单模块、小页面数，可以暂缓。
- 如果后续拆 HAR/HSP 或需要按需动态加载页面，再使用系统路由表。
- 使用系统路由表时，`module.json5` 必须配置 `routerMap`，页面必须提供匹配的 `@Builder` 入口。

## ArkUI 状态管理

第一版使用成熟稳定的 `@Component` 体系。

要求：

- 不强制使用 `@ComponentV2`。
- 不混用 V1/V2 状态管理，除非有明确局部收益和编译验证。
- 页面状态保留在 ViewModel 或页面 `@State`。
- 用户设置从 `PreferencesService` 加载后进入 `AppSettings`。
- 子组件通过 `@Prop` 或显式参数接收只读配置，避免子组件直接读全局存储。

## 架构分层

保持简单的 View / ViewModel / Service 分层：

- View 只负责渲染和触发用户动作。
- ViewModel 负责页面状态、发送流程、错误提示和节流持久化。
- Service 负责网络、RDB、Preferences、搜索 provider 等平台或外部能力。
- Model 只放类型定义，不混入网络请求和页面跳转。
- EntryAbility 只做生命周期、窗口、安全区和初始化注入，不写聊天业务。

这条线比抽象更多层更重要。新客户端要小而清楚，不能第一版就变成一团“可扩展但没人敢动”的框架。

## 工程约束

- 所有用户可见中文文案使用 UTF-8。
- API Key、完整 prompt、完整回复不得写入日志。
- 设置写入失败必须给用户轻提示。
- Preferences 迁移要有默认值兜底。
- 删除会话、清空数据不能误删 Preferences 中的主题、字号、背景设置，除非用户选择“重置所有设置”。

## 测试清单

必须覆盖：

- 首次启动读取默认设置。
- 修改主题后重启仍生效。
- 修改字号后消息、Markdown、输入栏同步变化。
- 修改背景设置后重启仍生效。
- Preferences 写入失败路径。
- 清空会话不清空用户偏好。
- 重置设置恢复默认值但不删除聊天记录。
