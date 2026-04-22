import { APP_NAME } from '../shared/Constants';
import { ChatMessage, Conversation, MessageRole, SendStatus, createConversation, createConversationTitle, createMessage } from '../models/ChatModels';

@Entry
@Component
struct Index {
  @State conversations: Conversation[] = [];
  @State currentConversationId: string = '';
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State isSidebarOpen: boolean = false;
  @State webSearchEnabled: boolean = false;
  @State bgEnabled: boolean = false;
  @State bgImageUri: string = '';
  @State bgOpacity: number = 0.3;

  aboutToAppear(): void {
    if (this.conversations.length === 0) {
      const conversation: Conversation = createConversation('New chat');
      this.conversations = [conversation];
      this.currentConversationId = conversation.id;
      this.messages = [];
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
  }

  @Builder
  private BackgroundLayer() {
    if (this.bgEnabled && this.bgImageUri.length > 0) {
      Image(this.bgImageUri)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(this.bgOpacity)
    }
  }

  @Builder
  private ChatLayer() {
    List() {
      if (this.messages.length === 0) {
        ListItem() {
          this.EmptyState()
        }
      } else {
        ForEach(this.messages, (message: ChatMessage) => {
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
            .fontSize(15)
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
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(19)
          }
          Text(message.content)
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
          if (message.status === SendStatus.FAILED && message.errorMessage.length > 0) {
            Text(message.errorMessage)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
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
            this.createNewConversation();
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
      Button(this.webSearchEnabled ? 'Search On' : 'Search')
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(19)
        .height(38)
        .onClick((): void => {
          this.webSearchEnabled = !this.webSearchEnabled;
        })

      Row({ space: 8 }) {
        TextArea({ placeholder: 'Ask DeepSeek', text: this.inputText })
          .placeholderColor($r('app.color.text_placeholder'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .maxLines(6)
          .constraintSize({ minHeight: 34, maxHeight: 132 })
          .onChange((value: string): void => {
            this.inputText = value;
          })

        Button(this.isLoading ? 'Stop' : 'Send')
          .fontSize(13)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(18)
          .height(36)
          .onClick((): void => {
            if (this.isLoading) {
              this.stopGenerating();
            } else {
              this.sendMessage();
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
            this.createNewConversation();
            this.isSidebarOpen = false;
          })

        List() {
          ForEach(this.conversations, (conversation: Conversation) => {
            ListItem() {
              Text(conversation.title)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                .backgroundColor(conversation.id === this.currentConversationId ? $r('app.color.bubble_user') : Color.Transparent)
                .borderRadius(8)
                .onClick((): void => {
                  this.switchConversation(conversation.id);
                  this.isSidebarOpen = false;
                })
            }
          }, (conversation: Conversation): string => conversation.id)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Button('Settings')
          .width('100%')
          .height(40)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(8)
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

  private sendMessage(): void {
    const content: string = this.inputText.trim();
    if (content.length === 0 || this.isLoading) {
      return;
    }

    const conversationId: string = this.ensureConversation();
    const userMessage: ChatMessage = createMessage(conversationId, MessageRole.USER, content);
    userMessage.status = SendStatus.SUCCESS;

    const assistantMessage: ChatMessage = createMessage(conversationId, MessageRole.ASSISTANT, 'API Key settings and streaming service are the next implementation step.');
    assistantMessage.status = SendStatus.SUCCESS;

    this.messages = this.messages.concat([userMessage, assistantMessage]);
    this.inputText = '';
    this.updateCurrentConversation(content);
  }

  private stopGenerating(): void {
    this.isLoading = false;
    const updated: ChatMessage[] = this.messages.slice();
    for (let i = updated.length - 1; i >= 0; i--) {
      if (updated[i].role === MessageRole.ASSISTANT && updated[i].status === SendStatus.SENDING) {
        updated[i].status = SendStatus.CANCELED;
        updated[i].updatedAt = Date.now();
        break;
      }
    }
    this.messages = updated;
  }

  private createNewConversation(): void {
    const conversation: Conversation = createConversation('New chat');
    this.conversations = [conversation].concat(this.conversations);
    this.currentConversationId = conversation.id;
    this.messages = [];
  }

  private switchConversation(id: string): void {
    const conversation: Conversation | null = this.findConversation(id);
    if (conversation === null) {
      return;
    }
    this.currentConversationId = conversation.id;
    this.messages = conversation.messages;
  }

  private updateCurrentConversation(firstMessage: string): void {
    const updated: Conversation[] = this.conversations.slice();
    for (let i = 0; i < updated.length; i++) {
      if (updated[i].id === this.currentConversationId) {
        if (updated[i].messages.length === 0) {
          updated[i].title = createConversationTitle(firstMessage);
        }
        updated[i].messages = this.messages;
        updated[i].updatedAt = Date.now();
        break;
      }
    }
    this.conversations = updated;
  }

  private ensureConversation(): string {
    if (this.currentConversationId.length > 0 && this.findConversation(this.currentConversationId) !== null) {
      return this.currentConversationId;
    }
    const conversation: Conversation = createConversation('New chat');
    this.conversations = [conversation].concat(this.conversations);
    this.currentConversationId = conversation.id;
    this.messages = [];
    return conversation.id;
  }

  private findConversation(id: string): Conversation | null {
    for (let i = 0; i < this.conversations.length; i++) {
      if (this.conversations[i].id === id) {
        return this.conversations[i];
      }
    }
    return null;
  }

  private getCurrentTitle(): string {
    const conversation: Conversation | null = this.findConversation(this.currentConversationId);
    if (conversation === null) {
      return 'New chat';
    }
    return conversation.title;
  }
}
