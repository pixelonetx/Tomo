import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { APP_NAME } from '../shared/Constants';
import { ChatMessage, Conversation, MessageRole, SendStatus } from '../models/ChatModels';
import { ChatViewModel } from '../viewmodels/ChatViewModel';

@Entry
@Component
struct Index {
  @State isSidebarOpen: boolean = false;
  @State showApiKeySheet: boolean = false;
  @State showMessageDetailSheet: boolean = false;
  @State selectedMessageId: string = '';
  @State vm: ChatViewModel = new ChatViewModel();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.vm.init(context as common.Context);
    }
  }

  build() {
    Stack() {
      this.BackgroundLayer();
      this.ChatLayer();
      if (this.isSidebarOpen) {
        this.SidebarLayer();
      }
      this.TopOverlay();
      this.BottomOverlay();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .bindSheet(this.showApiKeySheet, this.ApiKeySheetContent(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      onDisappear: (): void => {
        this.showApiKeySheet = false;
      }
    })
    .bindSheet(this.showMessageDetailSheet, this.MessageDetailSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      onDisappear: (): void => {
        this.showMessageDetailSheet = false;
      }
    })
  }

  @Builder
  private BackgroundLayer() {
    if (this.vm.backgroundEnabled && this.vm.backgroundImageUri.length > 0) {
      Image(this.vm.backgroundImageUri)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(this.vm.backgroundOpacity)
    }
  }

  @Builder
  private ChatLayer() {
    List() {
      if (this.vm.messages.length === 0) {
        ListItem() {
          this.EmptyState()
        }
      } else {
        ForEach(this.vm.messages, (message: ChatMessage) => {
          ListItem() {
            this.MessageRow(message)
          }
        }, (message: ChatMessage): string => message.id)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 112, bottom: 132 })
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  @Builder
  private EmptyState() {
    Column({ space: 12 }) {
      Text(APP_NAME)
        .fontSize(26)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('Ask with DeepSeek Chat or Reasoner. Search stays off until you choose it.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(21)
        .width('78%')
    }
    .width('100%')
    .height(320)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private MessageRow(message: ChatMessage) {
    Row() {
      if (message.role === MessageRole.USER) {
        Blank()
        Column() {
          Text(message.content)
            .fontSize(this.vm.fontSize)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
        }
        .constraintSize({ maxWidth: '74%' })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.bubble_user'))
        .borderRadius(14)
      } else {
        Column({ space: 8 }) {
          if (message.reasoningContent.length > 0) {
            Text(`Reasoning: ${message.reasoningContent}`)
              .fontSize(Math.max(this.vm.fontSize - 2, 12))
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(19)
          }
          Text(message.content)
            .fontSize(this.vm.fontSize)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
          if (message.status === SendStatus.FAILED && message.errorMessage.length > 0) {
            Text(message.errorMessage)
              .fontSize(Math.max(this.vm.fontSize - 2, 12))
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })

    Row({ space: 12 }) {
      Blank()
        .layoutWeight(message.role === MessageRole.USER ? 1 : 0)

      Button('Copy')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height(28)
        .onClick((): void => {
          this.copyText(message.content);
        })

      Button('Details')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height(28)
        .onClick((): void => {
          this.selectedMessageId = message.id;
          this.showMessageDetailSheet = true;
        })

      if (message.role === MessageRole.ASSISTANT && message.status === SendStatus.FAILED) {
        Button('Retry')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent)
          .height(28)
          .onClick((): void => {
            this.vm.retryLastMessage();
          })
      }

      Button('Delete')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height(28)
        .onClick((): void => {
          this.vm.deleteMessage(message.id);
        })
    }
    .width('100%')
  }

  @Builder
  private TopOverlay() {
    Column() {
      Row()
        .width('100%')
        .height(108)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [$r('app.color.top_bar_gradient_start'), 0.0],
            [$r('app.color.top_bar_background'), 0.42],
            [$r('app.color.top_bar_gradient_end'), 1.0]
          ]
        })
      Row() {
        Button('Menu')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.top_bar_background'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(19)
          .height(38)
          .onClick((): void => {
            this.isSidebarOpen = !this.isSidebarOpen;
          })

        Blank()

        Text(this.getCurrentTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        Button('New')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.top_bar_background'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(19)
          .height(38)
          .onClick((): void => {
            this.vm.createNewConversation();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 18, right: 18 })
      .position({ x: 0, y: 24 })
    }
    .width('100%')
    .height(108)
    .position({ x: 0, y: 0 })
  }

  @Builder
  private BottomOverlay() {
    Column() {
      Blank()
      Row()
        .width('100%')
        .height(118)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [$r('app.color.bottom_bar_gradient_start'), 0.0],
            [$r('app.color.top_bar_background'), 0.42],
            [$r('app.color.bottom_bar_gradient_end'), 1.0]
          ]
        })
      this.ChatInputBar()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  private ChatInputBar() {
    Row({ space: 8 }) {
      Button(this.vm.webSearchEnabled ? 'Search On' : 'Search')
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(19)
        .height(38)
        .onClick((): void => {
          this.vm.toggleWebSearch();
        })

      Row({ space: 8 }) {
        TextArea({ placeholder: 'Ask DeepSeek', text: this.vm.inputText })
          .placeholderColor($r('app.color.text_placeholder'))
          .fontSize(this.vm.fontSize)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .maxLines(6)
          .constraintSize({ minHeight: 34, maxHeight: 132 })
          .onChange((value: string): void => {
            this.vm.inputText = value;
          })

        Button(this.vm.isLoading ? 'Stop' : 'Send')
          .fontSize(13)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(18)
          .height(36)
          .onClick((): void => {
            if (this.vm.isLoading) {
              this.vm.stopGenerating();
            } else {
              this.vm.sendMessage();
            }
          })
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 44 })
      .padding({ left: 16, right: 8, top: 4, bottom: 4 })
      .backgroundColor($r('app.color.input_bar_background'))
      .border({ width: 1, color: $r('app.color.input_border') })
      .borderRadius(24)
    }
    .width('100%')
    .padding({ left: 8, right: 8, bottom: 12 })
  }

  @Builder
  private SidebarLayer() {
    Row() {
      Column({ space: 14 }) {
        Text(APP_NAME)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Button('New chat')
          .width('100%')
          .height(40)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(8)
          .onClick((): void => {
            this.vm.createNewConversation();
            this.isSidebarOpen = false;
          })

        List() {
          ForEach(this.vm.conversations, (conversation: Conversation) => {
            ListItem() {
              Text(conversation.title)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                .backgroundColor(conversation.id === this.vm.currentConversationId ? $r('app.color.bubble_user') : Color.Transparent)
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.switchConversation(conversation.id);
                  this.isSidebarOpen = false;
                })
            }
          }, (conversation: Conversation): string => conversation.id)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Button(this.vm.apiKeyConfigured ? 'API Key configured' : 'Set API Key')
          .width('100%')
          .height(40)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(8)
          .onClick((): void => {
            this.showApiKeySheet = true;
            this.isSidebarOpen = false;
          })
      }
      .width(300)
      .height('100%')
      .padding({ left: 18, right: 18, top: 56, bottom: 18 })
      .backgroundColor($r('app.color.page_background'))

      Blank()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#66000000')
        .onClick((): void => {
          this.isSidebarOpen = false;
        })
    }
    .width('100%')
    .height('100%')
    .zIndex(4)
  }

  @Builder
  private ApiKeySheetContent() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('DeepSeek API Key')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('Saved locally in this app sandbox via Preferences for the first version. Move to system secure storage is planned before broader release.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
      .width('100%')

      TextInput({ placeholder: 'sk-...', text: this.vm.apiKeyDraft })
        .type(InputType.Password)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_placeholder'))
        .backgroundColor($r('app.color.input_bar_background'))
        .border({ width: 1, color: $r('app.color.input_border') })
        .borderRadius(10)
        .height(46)
        .padding({ left: 12, right: 12 })
        .onChange((value: string): void => {
          this.vm.apiKeyDraft = value;
        })

      if (this.vm.settingsMessage.length > 0) {
        Text(this.vm.settingsMessage)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      Row({ space: 10 }) {
        Button('Clear')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.vm.clearApiKey();
          })

        Button('Check')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.vm.checkApiKey();
          })

        Button('Save')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(10)
          .onClick((): void => {
            this.vm.saveApiKey(this.vm.apiKeyDraft);
            this.showApiKeySheet = false;
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private MessageDetailSheetContent() {
    Column({ space: 16 }) {
      Text('Message details')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      this.DetailRow('Role', this.getSelectedMessageRole())
      this.DetailRow('Status', this.getSelectedMessageStatus())
      this.DetailRow('Model', this.getSelectedMessageModel())
      this.DetailRow('Finish reason', this.getSelectedMessageFinishReason())
      this.DetailRow('Response ID', this.getSelectedMessageResponseId())
      this.DetailRow('Prompt tokens', this.getSelectedMessagePromptTokens())
      this.DetailRow('Completion tokens', this.getSelectedMessageCompletionTokens())
      this.DetailRow('Reasoning tokens', this.getSelectedMessageReasoningTokens())
      this.DetailRow('Total tokens', this.getSelectedMessageTotalTokens())
      this.DetailRow('Cache hit / miss', this.getSelectedMessageCacheTokens())

      Row({ space: 10 }) {
        Button('Copy message')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.copyText(this.getSelectedMessageContent());
          })

        Button('Copy details')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(10)
          .onClick((): void => {
            this.copyText(this.getSelectedMessageDetailsText());
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(128)
      Text(value.length > 0 ? value : '-')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  private getCurrentTitle(): string {
    return this.vm.getCurrentTitle();
  }

  private copyText(text: string): void {
    if (text.length === 0) {
      this.showToast('Nothing to copy');
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then((): void => {
        this.showToast('Copied');
      }).catch((_err: Error): void => {
        this.showToast('Copy failed');
      });
    } catch (err) {
      this.showToast('Copy failed');
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().openToast({
      message: message,
      duration: 1600
    }).catch((_err: Error): void => {
    });
  }

  private getSelectedMessage(): ChatMessage | null {
    const messages: ChatMessage[] = this.vm.messages;
    const selectedMessageId: string = this.selectedMessageId;
    for (let i = 0; i < messages.length; i++) {
      if (messages[i].id === selectedMessageId) {
        return messages[i];
      }
    }
    return null;
  }

  private getSelectedMessageContent(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.content;
  }

  private getSelectedMessageRole(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.role;
  }

  private getSelectedMessageStatus(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.status;
  }

  private getSelectedMessageModel(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.model;
  }

  private getSelectedMessageFinishReason(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.finishReason;
  }

  private getSelectedMessageResponseId(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '';
    }
    return message.responseId;
  }

  private getSelectedMessagePromptTokens(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0';
    }
    return `${message.promptTokens}`;
  }

  private getSelectedMessageCompletionTokens(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0';
    }
    return `${message.completionTokens}`;
  }

  private getSelectedMessageReasoningTokens(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0';
    }
    return `${message.reasoningTokens}`;
  }

  private getSelectedMessageTotalTokens(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0';
    }
    return `${message.totalTokens}`;
  }

  private getSelectedMessageCacheTokens(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0 / 0';
    }
    return `${message.cacheHitTokens} / ${message.cacheMissTokens}`;
  }

  private getSelectedMessageDetailsText(): string {
    return `Role: ${this.getSelectedMessageRole()}\n` +
      `Status: ${this.getSelectedMessageStatus()}\n` +
      `Model: ${this.getSelectedMessageModel()}\n` +
      `Finish reason: ${this.getSelectedMessageFinishReason()}\n` +
      `Response ID: ${this.getSelectedMessageResponseId()}\n` +
      `Prompt tokens: ${this.getSelectedMessagePromptTokens()}\n` +
      `Completion tokens: ${this.getSelectedMessageCompletionTokens()}\n` +
      `Reasoning tokens: ${this.getSelectedMessageReasoningTokens()}\n` +
      `Total tokens: ${this.getSelectedMessageTotalTokens()}\n` +
      `Cache hit / miss: ${this.getSelectedMessageCacheTokens()}`;
  }
}
