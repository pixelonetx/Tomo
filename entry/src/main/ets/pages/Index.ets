import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { APP_NAME } from '../shared/Constants';
import { MarkdownMessageView } from '../components/MarkdownMessageView';
import { ApiKeySettingsPanel, SettingsView } from '../components/SettingsView';
import { DangerConfirmSheet, EditMessageSheet, MessageDetailSheet } from '../components/MessageSheets';
import { ChatMessage, Conversation, MessageRole, SendStatus } from '../models/ChatModels';
import { WEB_BROWSER_ROUTE, WebBrowserDestination, WebBrowserParam } from './WebBrowser';
import { ChatViewModel } from '../viewmodels/ChatViewModel';

const SETTINGS_ROUTE: string = 'Settings';

@Entry
@Component
struct Index {
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @State isSidebarOpen: boolean = false;
  @State showApiKeySheet: boolean = false;
  @State showMessageDetailSheet: boolean = false;
  @State showAboutSheet: boolean = false;
  @State showEditMessageSheet: boolean = false;
  @State showDangerConfirmSheet: boolean = false;
  @State pendingDangerAction: string = '';
  @State pendingDeleteMessageId: string = '';
  @State selectedMessageId: string = '';
  @State editMessageDraft: string = '';
  @State expandedReasoningIds: string[] = [];
  @State vm: ChatViewModel = new ChatViewModel();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.vm.init(context as common.Context);
    }
  }

  build() {
    Navigation(this.navPathStack) {
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
    .width('100%')
    .height('100%')
    .hideNavBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeMap)
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
    .bindSheet(this.showAboutSheet, this.AboutSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      onDisappear: (): void => {
        this.showAboutSheet = false;
      }
    })
    .bindSheet(this.showEditMessageSheet, this.EditMessageSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      onDisappear: (): void => {
        this.showEditMessageSheet = false;
      }
    })
    .bindSheet(this.showDangerConfirmSheet, this.DangerConfirmSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      onDisappear: (): void => {
        this.showDangerConfirmSheet = false;
      }
    })
  }

  @Builder
  private routeMap(name: string) {
    if (name === WEB_BROWSER_ROUTE) {
      WebBrowserDestination();
    }
    if (name === SETTINGS_ROUTE) {
      SettingsView(
        this.vm,
        (text: string): void => {
          this.copyText(text);
        },
        (format: string): void => {
          this.exportCurrentConversation(format);
        },
        (action: string): void => {
          this.showDangerConfirm(action);
        },
        (): void => {
          this.showAboutSheet = true;
        }
      );
    }
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
      if (this.vm.getVisibleMessages().length === 0) {
        ListItem() {
          this.EmptyState()
        }
      } else {
        ForEach(this.vm.getVisibleMessages(), (message: ChatMessage) => {
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
            this.ReasoningBlock(message)
          }
          MarkdownMessageView({
            content: message.content,
            fontSize: this.vm.fontSize,
            sources: message.searchSources,
            onOpenLink: (url: string, title: string): void => {
              this.openWebLink(url, title);
            }
          })
          if (message.status === SendStatus.FAILED && message.errorMessage.length > 0) {
            Text(message.errorMessage)
              .fontSize(Math.max(this.vm.fontSize - 2, 12))
              .fontColor($r('app.color.text_secondary'))
          }
          if (message.searchSources.length > 0) {
            Button(`Sources ${message.searchSources.length}`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor(Color.Transparent)
              .height(28)
              .onClick((): void => {
                this.selectedMessageId = message.id;
                this.showMessageDetailSheet = true;
              })
          }
          if (message.role === MessageRole.ASSISTANT && this.vm.getAssistantBranchCount(message) > 1) {
            Row({ space: 8 }) {
              Button('<')
                .width(36)
                .height(28)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.switchAssistantBranch(message.branchParentId, -1);
                })
              Text(`${this.vm.getAssistantBranchPosition(message)} / ${this.vm.getAssistantBranchCount(message)}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width(48)
              Button('>')
                .width(36)
                .height(28)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.switchAssistantBranch(message.branchParentId, 1);
                })
            }
            .width('100%')
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

      if (message.role === MessageRole.ASSISTANT && message.status !== SendStatus.SENDING) {
        Button('Regenerate')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent)
          .height(28)
          .onClick((): void => {
            this.vm.regenerateAssistantMessage(message.id);
          })
      }

      if (message.role === MessageRole.USER) {
        Button('Edit')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent)
          .height(28)
          .onClick((): void => {
            this.openEditMessageSheet(message);
          })
      }

      Button('Delete')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height(28)
        .onClick((): void => {
          this.showDeleteMessageConfirm(message.id);
        })
    }
    .width('100%')
  }

  @Builder
  private ReasoningBlock(message: ChatMessage) {
    Column({ space: 6 }) {
      Button(this.isReasoningExpanded(message.id) ? 'Hide reasoning' : this.getReasoningSummary(message))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height(28)
        .onClick((): void => {
          this.toggleReasoning(message.id);
        })

      if (this.isReasoningExpanded(message.id)) {
        Text(message.reasoningContent)
          .fontSize(Math.max(this.vm.fontSize - 2, 12))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.code_block_bg'))
          .borderRadius(8)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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

        Button('Settings')
          .width('100%')
          .height(40)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(8)
          .onClick((): void => {
            this.navPathStack.pushPath({ name: SETTINGS_ROUTE });
            this.isSidebarOpen = false;
          })

        Button('About & licenses')
          .width('100%')
          .height(40)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(8)
          .onClick((): void => {
            this.showAboutSheet = true;
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
    ApiKeySettingsPanel(
      this.vm,
      (): void => {
        this.showApiKeySheet = false;
      }
    );
  }

  @Builder
  private AboutSheetContent() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text(APP_NAME)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('A local HarmonyOS DeepSeek chat client. Third-party notices for bundled runtime assets are listed below.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
      .width('100%')

      Column({ space: 12 }) {
        this.OpenSourceLibraryBlock(
          'markdown-it',
          '14.1.1',
          'MIT',
          'CommonMark-compatible Markdown rendering, tables, links, emphasis, lists and fenced code blocks.',
          'https://github.com/markdown-it/markdown-it'
        )
        this.OpenSourceLibraryBlock(
          'KaTeX',
          '0.16.45',
          'MIT',
          'TeX math rendering for inline and display formulas inside assistant messages.',
          'https://katex.org/'
        )
      }
      .width('100%')

      Text('Bundled files are stored under resources/rawfile/markdown. Full license texts are included as LICENSE-markdown-it.txt and LICENSE-katex.txt.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .width('100%')

      Button('Copy notices')
        .width('100%')
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          this.copyText(this.getOpenSourceNoticesText());
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private OpenSourceLibraryBlock(name: string, version: string, license: string, usage: string, website: string) {
    Column({ space: 6 }) {
      Row() {
        Text(`${name} ${version}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(license)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(usage)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(19)
        .width('100%')

      Text(website)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(8)
  }

  @Builder
  private DangerConfirmSheetContent() {
    DangerConfirmSheet(
      this.getDangerConfirmTitle(),
      this.getDangerConfirmMessage(),
      this.getDangerConfirmActionText(),
      (): void => {
        this.showDangerConfirmSheet = false;
        this.pendingDangerAction = '';
        this.pendingDeleteMessageId = '';
      },
      (): void => {
        this.runDangerAction();
      }
    );
  }

  @Builder
  private MessageDetailSheetContent() {
    MessageDetailSheet(
      this.getSelectedMessage(),
      (text: string): void => {
        this.copyText(text);
      },
      (url: string, title: string): void => {
        this.openWebLink(url, title);
      },
      (): void => {
        this.showMessageDetailSheet = false;
      }
    );
  }

  @Builder
  private EditMessageSheetContent() {
    EditMessageSheet(
      this.editMessageDraft,
      this.vm.fontSize,
      (value: string): void => {
        this.editMessageDraft = value;
      },
      (): void => {
        this.showEditMessageSheet = false;
      },
      (): void => {
        this.vm.editUserMessageAndRegenerate(this.selectedMessageId, this.editMessageDraft);
        this.showEditMessageSheet = false;
      }
    );
  }

  private getCurrentTitle(): string {
    return this.vm.getCurrentTitle();
  }

  private openEditMessageSheet(message: ChatMessage): void {
    this.selectedMessageId = message.id;
    this.editMessageDraft = message.content;
    this.showEditMessageSheet = true;
  }

  private getApiKeyButtonText(): string {
    if (this.vm.apiKeyConfigured && this.vm.searchApiKeyConfigured) {
      return 'API Keys configured';
    }
    if (this.vm.apiKeyConfigured) {
      return 'Set Search Key';
    }
    return 'Set API Key';
  }

  private isReasoningExpanded(messageId: string): boolean {
    return this.expandedReasoningIds.indexOf(messageId) >= 0;
  }

  private toggleReasoning(messageId: string): void {
    const ids: string[] = this.expandedReasoningIds.slice();
    const index: number = ids.indexOf(messageId);
    if (index >= 0) {
      ids.splice(index, 1);
    } else {
      ids.push(messageId);
    }
    this.expandedReasoningIds = ids;
  }

  private getReasoningSummary(message: ChatMessage): string {
    if (message.reasoningTokens > 0) {
      return `Reasoning ${message.reasoningTokens} tokens`;
    }
    return `Reasoning ${message.reasoningContent.length} chars`;
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

  private async exportCurrentConversation(format: string): Promise<void> {
    if (format === 'json') {
      await this.saveTextFile(this.vm.getCurrentConversationJson(), this.vm.getCurrentConversationExportName('json'));
      return;
    }
    await this.saveTextFile(this.vm.getCurrentConversationMarkdown(), this.vm.getCurrentConversationExportName('md'));
  }

  private async saveTextFile(content: string, fileName: string): Promise<void> {
    if (content.length === 0) {
      this.showToast('Nothing to export');
      return;
    }
    let file: fileIo.File | null = null;
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.save(options);
      if (uris.length === 0) {
        return;
      }
      file = fileIo.openSync(uris[0], fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const encoder = util.TextEncoder.create('utf-8');
      const bytes: Uint8Array = encoder.encodeInto(content);
      fileIo.writeSync(file.fd, bytes.buffer);
      this.showToast('Exported');
    } catch (err) {
      this.showToast('Export failed');
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file.fd);
        } catch (_err) {
        }
      }
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().openToast({
      message: message,
      duration: 1600
    }).catch((_err: Error): void => {
    });
  }

  private showDangerConfirm(action: string): void {
    this.pendingDangerAction = action;
    this.pendingDeleteMessageId = '';
    this.showDangerConfirmSheet = true;
  }

  private showDeleteMessageConfirm(messageId: string): void {
    this.pendingDangerAction = 'message';
    this.pendingDeleteMessageId = messageId;
    this.showDangerConfirmSheet = true;
  }

  private getDangerConfirmTitle(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Clear settings';
    }
    if (this.pendingDangerAction === 'message') {
      return 'Delete message';
    }
    return 'Clear chats';
  }

  private getDangerConfirmMessage(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Reset local settings and remove encrypted DeepSeek and Tavily keys?';
    }
    if (this.pendingDangerAction === 'message') {
      return 'Delete this local message from the conversation?';
    }
    return 'Delete all local conversations on this device?';
  }

  private getDangerConfirmActionText(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Clear settings';
    }
    if (this.pendingDangerAction === 'message') {
      return 'Delete';
    }
    return 'Clear chats';
  }

  private runDangerAction(): void {
    const action: string = this.pendingDangerAction;
    const messageId: string = this.pendingDeleteMessageId;
    this.showDangerConfirmSheet = false;
    this.pendingDangerAction = '';
    this.pendingDeleteMessageId = '';
    if (action === 'settings') {
      this.vm.resetLocalSettingsAndKeys();
      return;
    }
    if (action === 'message') {
      this.vm.deleteMessage(messageId);
      return;
    }
    if (action === 'chats') {
      this.vm.clearAllConversations();
    }
  }

  private openWebLink(url: string, title: string): void {
    const param: WebBrowserParam = {
      url: url,
      title: title
    };
    this.navPathStack.pushPath({
      name: WEB_BROWSER_ROUTE,
      param: param
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

  private getOpenSourceNoticesText(): string {
    return `${APP_NAME} open source notices\n\n` +
      'markdown-it 14.1.1\n' +
      'License: MIT\n' +
      'Website: https://github.com/markdown-it/markdown-it\n' +
      'Usage: CommonMark-compatible Markdown rendering, tables, links, emphasis, lists and fenced code blocks.\n\n' +
      'KaTeX 0.16.45\n' +
      'License: MIT\n' +
      'Website: https://katex.org/\n' +
      'Usage: TeX math rendering for inline and display formulas inside assistant messages.\n\n' +
      'Bundled license files:\n' +
      'resources/rawfile/markdown/LICENSE-markdown-it.txt\n' +
      'resources/rawfile/markdown/LICENSE-katex.txt';
  }

}
