# 首页 UI 蓝图

这份文档描述首页应该如何实现。

目标不是做复杂界面，而是做一个轻盈、通透、安静的 DeepSeek 对话首页。核心视觉是：背景层、顶部渐变、底部渐变、悬浮输入栏、干净消息流。

## 页面结构

```text
Index
  Stack
    BackgroundLayer
    SideBarContainer
      SidebarPanel
      Stack
        MessageList
        TopGradientOverlay
        TopBar
        BottomGradientOverlay
        ChatInputBar
        ScrollToBottomButton
    ApiKeySheet
```

## 状态字段

```ts
@Local vm: ChatViewModel = new ChatViewModel()
@Local isSidebarOpen: boolean = false
@Local showApiKeySheet: boolean = false
@Local searchText: string = ''
@Local bgEnabled: boolean = false
@Local bgImageUri: string = ''
@Local bgBlurRadius: number = 20
@Local bgOpacity: number = 0.3
@Local topSafeHeight: number = 0
@Local bottomSafeHeight: number = 0
@Local keyboardHeight: number = 0
@Local showScrollToBottom: boolean = false
@Local viewportWidth: number = 760
private navStack: NavPathStack = new NavPathStack()
private listScroller: ListScroller = new ListScroller()
```

## 根布局

```ts
build() {
  Stack() {
    this.MainContent()
  }
  .width('100%')
  .height('100%')
  .onAreaChange((_oldValue, newValue): void => {
    const nextWidth: number = this.getUIContext().px2vp(newValue.width as number)
    if (nextWidth > 0) {
      this.viewportWidth = nextWidth
      if (!this.usesOverlaySidebar()) {
        this.isSidebarOpen = true
      }
    }
  })
}
```

## 主内容

```ts
@Builder
MainContent() {
  Navigation(this.navStack) {
    SideBarContainer(this.getSidebarContainerType()) {
      SidebarPanel({
        conversations: this.vm.conversations,
        currentId: this.getCurrentConversationId(),
        searchText: this.searchText,
        topSafeHeight: this.getTopPadding(),
        bottomSafeHeight: this.getBottomPadding(),
        onSelectConversation: (id: string): void => {
          this.vm.switchConversation(id)
          this.closeSidebar()
        },
        onNewChat: (): void => {
          this.vm.createNewConversation()
          this.closeSidebar()
        },
        onDeleteConversation: (id: string): void => {
          this.vm.deleteConversation(id)
        },
        onOpenSettings: (): void => {
          this.closeSidebar()
          this.navStack.pushPath({ name: 'settings' })
        },
        onSearchChange: (text: string): void => {
          this.searchText = text
        }
      })

      Stack() {
        this.BackgroundLayer()
        this.MessagePage()
        this.OverlayLayer()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .sideBarWidth(this.getAdaptiveSidebarWidth())
    .showSideBar(this.isSidebarOpen)
    .showControlButton(false)
    .autoHide(this.usesOverlaySidebar())
  }
  .hideTitleBar(true)
  .mode(NavigationMode.Stack)
  .bindSheet(
    this.showApiKeySheet,
    this.ApiKeySheetContent(),
    {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      dragBar: true,
      onDisappear: (): void => {
        this.showApiKeySheet = false
      }
    }
  )
}
```

## 背景层

```ts
@Builder
BackgroundLayer() {
  if (this.bgEnabled && this.bgImageUri.length > 0) {
    Image(this.bgImageUri)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .foregroundBlurStyle(this.resolveBackgroundBlurStyle(), {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1
      })
      .opacity(this.bgOpacity)
  }
}
```

```ts
private resolveBackgroundBlurStyle(): BlurStyle {
  if (this.bgBlurRadius >= 60) {
    return BlurStyle.BACKGROUND_ULTRA_THICK
  }
  if (this.bgBlurRadius >= 36) {
    return BlurStyle.BACKGROUND_THICK
  }
  if (this.bgBlurRadius >= 18) {
    return BlurStyle.BACKGROUND_REGULAR
  }
  if (this.bgBlurRadius > 0) {
    return BlurStyle.BACKGROUND_THIN
  }
  return BlurStyle.Thin
}
```

## 消息列表

```ts
@Builder
MessagePage() {
  Stack({ alignContent: Alignment.BottomEnd }) {
    List({ scroller: this.listScroller }) {
      ForEach(this.getMessages(), (msg: ChatMessage, index: number) => {
        ListItem() {
          MessageBubble({
            message: msg,
            fontSize: this.vm.fontSize,
            maxBubbleWidth: this.getAdaptiveMessageBubbleWidth(),
            onCopy: (content: string): void => {
              this.copyToClipboard(content)
            },
            onRetry: (): void => {
              this.vm.retryLastMessage()
            },
            onDelete: (): void => {
              this.vm.deleteMessage(msg.id)
            },
            onEdit: (content: string): void => {
              this.vm.inputText = content
            },
            onOpenLink: (url: string): void => {
              this.openUrl(url)
            }
          })
        }
        .margin({
          top: index === 0 ? this.getTopPadding() + 68 : 0,
          bottom: index === this.getMessages().length - 1 ? this.getInputOverlayPadding() : 0
        })
      }, (msg: ChatMessage): string => msg.id)
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }
  .width('100%')
  .height('100%')
}
```

## 覆盖层

```ts
@Builder
OverlayLayer() {
  Stack() {
    this.TopGradientOverlay()
    this.TopBar()
    this.BottomGradientOverlay()
    this.BottomInput()
  }
  .width('100%')
  .height('100%')
  .hitTestBehavior(HitTestMode.Transparent)
}
```

注意：`OverlayLayer` 本身透明穿透，但 `TopBar` 和 `BottomInput` 内部需要可点击区域时，应在具体组件上恢复点击行为。

## 顶部渐变

```ts
@Builder
TopGradientOverlay() {
  Row()
    .width('100%')
    .height(this.getTopPadding() + 96)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        [$r('app.color.top_bar_gradient_start'), 0.0],
        [$r('app.color.top_bar_background'), 0.34],
        [$r('app.color.top_bar_background'), 0.56],
        [$r('app.color.top_bar_gradient_end'), 1.0]
      ]
    })
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
}
```

## 顶部栏

```ts
@Builder
TopBar() {
  Row() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.sidebar_left'))
        .fontSize(19)
        .fontColor([$r('app.color.icon_primary')])
    }
    .size({ width: 38, height: 38 })
    .backgroundColor($r('app.color.top_bar_background'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(9999)
    .onClick((): void => {
      this.isSidebarOpen = !this.isSidebarOpen
    })

    Blank()

    Text(this.getCurrentTitle())
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })

    Blank()

    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(18)
        .fontColor([$r('app.color.icon_primary')])
    }
    .size({ width: 38, height: 38 })
    .backgroundColor($r('app.color.top_bar_background'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(9999)
    .onClick((): void => {
      this.vm.createNewConversation()
    })
  }
  .height(56)
  .width('100%')
  .padding({
    left: 18,
    right: 18,
    top: this.getTopPadding()
  })
  .position({ x: 0, y: 0 })
}
```

## 底部渐变

```ts
@Builder
BottomGradientOverlay() {
  Row()
    .width('100%')
    .height(this.getInputOverlayPadding() + 36)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        [$r('app.color.bottom_bar_gradient_start'), 0.0],
        [$r('app.color.top_bar_background'), 0.52],
        [$r('app.color.bottom_bar_gradient_end'), 1.0]
      ]
    })
    .position({ x: 0, y: '100%' })
    .translate({ y: -(this.getInputOverlayPadding() + 36) })
    .hitTestBehavior(HitTestMode.Transparent)
}
```

## 底部输入栏

```ts
@Builder
BottomInput() {
  Column() {
    ChatInputBar({
      inputText: this.vm.inputText,
      isLoading: this.vm.isLoading,
      bottomSafeHeight: this.getBottomPadding(),
      maxContentWidth: this.getAdaptiveContentWidth(),
      horizontalPadding: 8,
      onInputChange: (text: string): void => {
        this.vm.inputText = text
      },
      onSend: (): void => {
        this.vm.sendMessage()
      },
      onStop: (): void => {
        this.vm.stopGenerating()
      },
      onOpenAttachments: (): void => {
        this.openAttachmentMenu()
      },
      onToggleVoiceRecording: (): void => {
        this.toggleVoiceInput()
      }
    })
  }
  .width('100%')
  .padding({
    bottom: this.keyboardHeight > 0 ? 8 : this.getBottomPadding() + 8
  })
  .position({ x: 0, y: '100%' })
  .translate({ y: -this.getInputOverlayPadding() })
}
```

## ChatInputBar 结构

```ts
Row() {
  Button({ type: ButtonType.Circle }) {
    SymbolGlyph($r('sys.symbol.plus'))
      .fontSize(17)
      .fontColor([$r('app.color.icon_secondary')])
  }
  .size({ width: 38, height: 38 })
  .backgroundColor($r('app.color.page_background'))
  .border({ width: 1, color: $r('app.color.divider') })
  .borderRadius(9999)

  Row({ space: 8 }) {
    TextArea({ placeholder: 'Ask DeepSeek', text: this.inputText })
      .placeholderColor($r('app.color.text_placeholder'))
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .backgroundColor(Color.Transparent)
      .layoutWeight(1)
      .maxLines(6)
      .constraintSize({ minHeight: 24, maxHeight: 132 })

    this.VoiceButton()
    this.SendButton()
  }
  .layoutWeight(1)
  .constraintSize({ minHeight: 44 })
  .padding({ left: 20, right: 10, top: 4, bottom: 4 })
  .backgroundColor($r('app.color.input_bar_background'))
  .borderRadius(9999)
  .border({ width: 1, color: $r('app.color.input_border') })
}
.width('100%')
.constraintSize({ maxWidth: this.maxContentWidth })
.padding({ left: this.horizontalPadding, right: this.horizontalPadding })
```

## 颜色资源

Light:

```json
{
  "color": [
    { "name": "page_background", "value": "#FFFFFF" },
    { "name": "input_bar_background", "value": "#FFFFFF" },
    { "name": "text_primary", "value": "#000000" },
    { "name": "text_secondary", "value": "#737373" },
    { "name": "text_placeholder", "value": "#A3A3A3" },
    { "name": "icon_primary", "value": "#000000" },
    { "name": "icon_secondary", "value": "#737373" },
    { "name": "divider", "value": "#E5E5E5" },
    { "name": "button_primary", "value": "#000000" },
    { "name": "text_on_primary", "value": "#FFFFFF" },
    { "name": "top_bar_background", "value": "#CCFFFFFF" },
    { "name": "top_bar_gradient_start", "value": "#EAFFFFFF" },
    { "name": "top_bar_gradient_end", "value": "#08FFFFFF" },
    { "name": "bottom_bar_gradient_start", "value": "#08FFFFFF" },
    { "name": "bottom_bar_gradient_end", "value": "#D6FFFFFF" },
    { "name": "input_border", "value": "#D4D4D4" },
    { "name": "bubble_user", "value": "#E5E5E5" },
    { "name": "code_block_bg", "value": "#FAFAFA" }
  ]
}
```

Dark:

```json
{
  "color": [
    { "name": "page_background", "value": "#000000" },
    { "name": "input_bar_background", "value": "#090909" },
    { "name": "text_primary", "value": "#EDEDED" },
    { "name": "text_secondary", "value": "#B0B0B0" },
    { "name": "text_placeholder", "value": "#737373" },
    { "name": "icon_primary", "value": "#EDEDED" },
    { "name": "icon_secondary", "value": "#B0B0B0" },
    { "name": "divider", "value": "#262626" },
    { "name": "button_primary", "value": "#EDEDED" },
    { "name": "text_on_primary", "value": "#0B0B0C" },
    { "name": "top_bar_background", "value": "#BC000000" },
    { "name": "top_bar_gradient_start", "value": "#DE000000" },
    { "name": "top_bar_gradient_end", "value": "#08000000" },
    { "name": "bottom_bar_gradient_start", "value": "#08000000" },
    { "name": "bottom_bar_gradient_end", "value": "#D2000000" },
    { "name": "input_border", "value": "#262626" },
    { "name": "bubble_user", "value": "#1A1A1A" },
    { "name": "code_block_bg", "value": "#090909" }
  ]
}
```

## 自适应规则

```ts
private isExpandedLayout(): boolean {
  return this.viewportWidth >= 1200
}

private isMediumLayout(): boolean {
  return this.viewportWidth >= 840 && this.viewportWidth < 1200
}

private usesOverlaySidebar(): boolean {
  return !this.isMediumLayout() && !this.isExpandedLayout()
}

private getAdaptiveContentWidth(): number {
  if (this.isExpandedLayout()) {
    return 1080
  }
  if (this.isMediumLayout()) {
    return 920
  }
  return 760
}

private getAdaptiveSidebarWidth(): number {
  if (this.isExpandedLayout()) {
    return 420
  }
  if (this.isMediumLayout()) {
    return 360
  }
  return 300
}
```

## 实现边界

必须保留：

- 顶部渐变透明。
- 底部渐变透明。
- 背景图模糊和透明度。
- 胶囊输入栏。
- 极简消息流。

不要加入：

- 卡片化工具结果。
- 技能中心。
- 大型功能卡片。
- 与对话无关的业务卡片。
- 任务状态面板。
- 工具日志面板。
