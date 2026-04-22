# UI 视觉与交互指南

## 总体视觉

应用采用轻盈、通透、安静的聊天界面：

- 渐变透明的顶部遮罩。
- 渐变透明的底部输入区遮罩。
- 可选背景图。
- 背景图前景模糊。
- 半透明输入栏。
- 轻质侧边栏。
- 消息流留白充足。
- 深浅色跟随系统，也允许用户在设置中覆盖。
- 字号可由用户设置，并在重启后恢复。

不要出现：

- 复杂卡片。
- 工具状态卡。
- 大型功能卡片。
- 功能市场产品入口。
- 工具日志面板。

## 页面结构

```text
Stack
  BackgroundLayer
  MainChatLayer
    SidebarPanel
    MessageList
    TopBar
    BottomInputOverlay
  Sheets
    ApiKeySheet
    SettingsSheet/Page
    WebSearch source details
```

## 背景层

背景层可以绘制延伸到系统安全区，但交互控件不能压到状态栏、导航区域或键盘区域。

如果用户启用背景图：

```ts
Image(bgImageUri)
  .width('100%')
  .height('100%')
  .objectFit(ImageFit.Cover)
  .foregroundBlurStyle(resolveBackgroundBlurStyle(), {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.DEFAULT,
    scale: 1
  })
  .opacity(bgOpacity)
```

默认值：

- `bgEnabled = false`
- `bgBlurRadius = 20`
- `bgOpacity = 0.3`

模糊映射：

```ts
if (blur >= 60) return BlurStyle.BACKGROUND_ULTRA_THICK
if (blur >= 36) return BlurStyle.BACKGROUND_THICK
if (blur >= 18) return BlurStyle.BACKGROUND_REGULAR
if (blur > 0) return BlurStyle.BACKGROUND_THIN
return BlurStyle.Thin
```

## 顶部遮罩

建议实现：

```ts
.linearGradient({
  direction: GradientDirection.Bottom,
  colors: [
    [$r('app.color.top_bar_gradient_start'), 0.0],
    [$r('app.color.top_bar_background'), 0.34],
    [$r('app.color.top_bar_background'), 0.56],
    [$r('app.color.top_bar_gradient_end'), 1.0]
  ]
})
.hitTestBehavior(HitTestMode.Transparent)
```

用途：

- 顶部安全区到导航栏自然过渡。
- 消息滚动到顶部时不会硬切。
- 视觉上像玻璃层，而不是普通 AppBar。
- 可配合 `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` 做绘制延伸。

## 底部遮罩

建议实现：

```ts
.linearGradient({
  direction: GradientDirection.Bottom,
  colors: [
    [$r('app.color.bottom_bar_gradient_start'), 0.0],
    [$r('app.color.top_bar_background'), 0.52],
    [$r('app.color.bottom_bar_gradient_end'), 1.0]
  ]
})
.hitTestBehavior(HitTestMode.Transparent)
```

用途：

- 输入栏悬浮时不压消息。
- 键盘和底部安全区过渡柔和。
- 可配合 `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])` 做绘制延伸。
- 输入栏本身仍需避让底部手势区和键盘。

## 推荐颜色

Light:

```json
{
  "page_background": "#FFFFFF",
  "input_bar_background": "#FFFFFF",
  "text_primary": "#000000",
  "text_secondary": "#737373",
  "text_placeholder": "#A3A3A3",
  "divider": "#E5E5E5",
  "button_primary": "#000000",
  "top_bar_background": "#CCFFFFFF",
  "top_bar_gradient_start": "#EAFFFFFF",
  "top_bar_gradient_end": "#08FFFFFF",
  "bottom_bar_gradient_start": "#08FFFFFF",
  "bottom_bar_gradient_end": "#D6FFFFFF",
  "bubble_user": "#E5E5E5",
  "code_block_bg": "#FAFAFA"
}
```

Dark:

```json
{
  "page_background": "#000000",
  "input_bar_background": "#090909",
  "text_primary": "#EDEDED",
  "text_secondary": "#B0B0B0",
  "text_placeholder": "#737373",
  "divider": "#262626",
  "button_primary": "#EDEDED",
  "top_bar_background": "#BC000000",
  "top_bar_gradient_start": "#DE000000",
  "top_bar_gradient_end": "#08000000",
  "bottom_bar_gradient_start": "#08000000",
  "bottom_bar_gradient_end": "#D2000000",
  "bubble_user": "#1A1A1A",
  "code_block_bg": "#090909"
}
```

## 输入栏

输入栏应是主视觉核心之一。

要求：

- 底部悬浮。
- 圆角胶囊。
- 半透明或纯白/纯黑轻质背景。
- 左侧附件按钮。
- 中间 `TextArea`。
- 右侧语音按钮和发送/停止按钮。
- 最大 6 行。
- loading 时发送按钮变停止按钮。

基础参数：

```ts
INPUT_BAR_MIN_HEIGHT = 44
INPUT_BAR_RADIUS = 9999
INPUT_BAR_MARGIN = 8
CONTENT_MAX_WIDTH = 760
PAGE_SIDE_PADDING = 18
```

占位文案建议：

```text
Ask DeepSeek
```

## 消息流

Assistant：

- 不使用气泡背景。
- 使用 Markdown 全宽排版。
- 左对齐。
- 行高 22。
- 字号 15 或用户设置字号。

User：

- 右侧气泡。
- 背景 `bubble_user`。
- 最大宽度 72%。
- 圆角 12。

Reasoning：

- 默认折叠。
- 标题为 `Reasoning`。
- 用户可展开。
- 颜色使用 `text_secondary`。

Action：

- 单行文字。
- 下划线。
- 不做卡片。

## Markdown

必须支持：

- 段落。
- 标题。
- 列表。
- 引用。
- inline code。
- fenced code block。
- 链接点击。
- 复制代码。

代码块：

- 顶部显示语言和 Copy。
- 背景使用 `code_block_bg`。
- 等宽字体。
- 横向滚动。

## 侧边栏

保留侧滑会话列表，但不要过度设计。

内容：

- 新建对话。
- 搜索会话。
- 会话列表。
- 设置入口。

交互：

- 小屏 Overlay。
- 中/大屏 Embed。
- 支持左滑打开、右滑关闭。

## 设置页

只暴露用户能理解的设置：

- API Key。
- 模型模式：Chat / Reasoner。
- 主题：系统 / 浅色 / 深色。
- 字号。
- 背景图。
- 背景模糊。
- 背景透明度。
- 数据管理。
- 关于。

这些设置必须通过 Preferences 持久化：

- 主题。
- 字号。
- 背景图。
- 背景模糊。
- 背景透明度。
- 默认模型。
- 联网搜索默认开关。

清空聊天记录不应清空这些偏好；只有“重置设置”才恢复默认值。

不要暴露：

- 功能市场。
- Tool。
- Workflow。
- 通用自动化框架。
- 外部协议客户端。
- 包诊断。

## 动效

保持克制：

- 页面切换 160 到 260ms。
- 消息出现轻微 opacity。
- 侧边栏跟手。
- 不做炫技动画。

## 可访问性

- 字号可调。
- 深浅色跟随系统。
- 按钮点击区域不小于 34vp。
- 错误文案清楚。
- 不只靠颜色表达状态。
- 用户字号变化后，消息正文、Markdown、代码块、输入栏都要同步变化。
