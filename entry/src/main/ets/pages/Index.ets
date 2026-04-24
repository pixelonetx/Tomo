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
    .backgroundColor($r('app.color.page_background'))
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
    .padding({ left: 20, right: 20, top: 96, bottom: 128 })
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  @Builder
  private EmptyState() {
    Column({ space: 14 }) {
      Text(APP_NAME)
        .fontSize(24)
        .fontWeight(FontWeight.Regular)
        .fontColor($r('app.color.text_primary'))
      Text('Ask with DeepSeek V4. Search stays off until you choose it.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(21)
        .constraintSize({ maxWidth: 420 })
    }
    .width('100%')
    .height(360)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ToolbarIconButton(icon: Resource, action: () => void) {
    Row() {
      Image(icon)
        .width(17)
        .height(17)
        .objectFit(ImageFit.Contain)
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_background'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(18)
    .onClick(action)
  }

  @Builder
  private PillIconButton(icon: Resource, label: string, action: () => void, selected: boolean = false, primary: boolean = false) {
    Row({ space: 6 }) {
      Image(icon)
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
      if (label.length > 0) {
        Text(label)
          .fontSize(13)
          .fontColor(primary ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
      }
    }
    .height(38)
    .padding({ left: label.length > 0 ? 12 : 10, right: label.length > 0 ? 12 : 10 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(primary ? $r('app.color.button_primary') : (selected ? $r('app.color.surface_pressed') : $r('app.color.surface_background')))
    .border({ width: primary ? 0 : 1, color: $r('app.color.divider') })
    .borderRadius(19)
    .onClick(action)
  }

  @Builder
  private MessageActionButton(icon: Resource, label: string, action: () => void) {
    Row({ space: 4 }) {
      Image(icon)
        .width(14)
        .height(14)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .height(30)
    .padding({ left: 6, right: 6 })
    .borderRadius(7)
    .onClick(action)
  }

  @Builder
  private SmallIconButton(icon: Resource, action: () => void) {
    Row() {
      Image(icon)
        .width(14)
        .height(14)
        .objectFit(ImageFit.Contain)
    }
    .width(36)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(8)
    .onClick(action)
  }

  @Builder
  private SidebarButton(icon: Resource, label: string, action: () => void, primary: boolean = false) {
    Row({ space: 8 }) {
      Image(icon)
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(14)
        .fontColor(primary ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 12 })
    .backgroundColor(primary ? $r('app.color.button_primary') : Color.Transparent)
    .border({ width: primary ? 0 : 1, color: $r('app.color.divider') })
    .borderRadius(8)
    .onClick(action)
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
            .lineHeight(23)
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: 16, right: 16, top: 11, bottom: 11 })
        .backgroundColor($r('app.color.bubble_user'))
        .borderRadius(18)
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
              this.SmallIconButton($r('app.media.lucide_chevron_left'), (): void => {
                this.vm.switchAssistantBranch(message.branchParentId, -1);
              })
              Text(`${this.vm.getAssistantBranchPosition(message)} / ${this.vm.getAssistantBranchCount(message)}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width(48)
              this.SmallIconButton($r('app.media.lucide_chevron_right'), (): void => {
                this.vm.switchAssistantBranch(message.branchParentId, 1);
              })
            }
            .width('100%')
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 860 })
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 6 })

    Row({ space: 12 }) {
      Blank()
        .layoutWeight(message.role === MessageRole.USER ? 1 : 0)

      this.MessageActionButton($r('app.media.lucide_copy'), 'Copy', (): void => {
        this.copyText(message.content);
      })

      this.MessageActionButton($r('app.media.lucide_info'), 'Details', (): void => {
        this.selectedMessageId = message.id;
        this.showMessageDetailSheet = true;
      })

      if (message.role === MessageRole.ASSISTANT && message.status === SendStatus.FAILED) {
        this.MessageActionButton($r('app.media.lucide_rotate_ccw'), 'Retry', (): void => {
          this.vm.retryLastMessage();
        })
      }

      if (message.role === MessageRole.ASSISTANT && message.status !== SendStatus.SENDING) {
        this.MessageActionButton($r('app.media.lucide_rotate_ccw'), 'Regenerate', (): void => {
          this.vm.regenerateAssistantMessage(message.id);
        })
      }

      if (message.role === MessageRole.USER) {
        this.MessageActionButton($r('app.media.lucide_pencil'), 'Edit', (): void => {
          this.openEditMessageSheet(message);
        })
      }

      this.MessageActionButton($r('app.media.lucide_trash_2'), 'Delete', (): void => {
        this.showDeleteMessageConfirm(message.id);
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: 860 })
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
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
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
        .height(94)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [$r('app.color.top_bar_gradient_start'), 0.0],
            [$r('app.color.top_bar_background'), 0.42],
            [$r('app.color.top_bar_gradient_end'), 1.0]
          ]
        })
      Row() {
        this.ToolbarIconButton($r('app.media.lucide_menu'), (): void => {
          this.isSidebarOpen = !this.isSidebarOpen;
        })

        Blank()

        Text(this.getCurrentTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        this.ToolbarIconButton($r('app.media.lucide_plus'), (): void => {
          this.vm.createNewConversation();
        })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .position({ x: 0, y: 20 })
    }
    .width('100%')
    .height(94)
    .position({ x: 0, y: 0 })
  }

  @Builder
  private BottomOverlay() {
    Column() {
      Blank()
      Row()
        .width('100%')
        .height(116)
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
      this.PillIconButton($r('app.media.lucide_search'), this.vm.webSearchEnabled ? 'Search on' : 'Search', (): void => {
        this.vm.toggleWebSearch();
      }, this.vm.webSearchEnabled)

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

        this.PillIconButton(this.vm.isLoading ? $r('app.media.lucide_square_on_primary') : $r('app.media.lucide_send_horizontal_on_primary'), '', (): void => {
          if (this.vm.isLoading) {
            this.vm.stopGenerating();
          } else {
            this.vm.sendMessage();
          }
        }, false, true)
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 44 })
      .padding({ left: 16, right: 8, top: 4, bottom: 4 })
      .backgroundColor($r('app.color.input_bar_background'))
      .border({ width: 1, color: $r('app.color.input_border') })
      .borderRadius(22)
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  private SidebarLayer() {
    Row() {
      Column({ space: 14 }) {
        Text(APP_NAME)
          .fontSize(18)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        this.SidebarButton($r('app.media.lucide_plus_on_primary'), 'New chat', (): void => {
          this.vm.createNewConversation();
          this.isSidebarOpen = false;
        }, true)

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
                .backgroundColor(conversation.id === this.vm.currentConversationId ? $r('app.color.surface_subtle') : Color.Transparent)
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

        this.SidebarButton($r('app.media.lucide_settings'), 'Settings', (): void => {
          this.navPathStack.pushPath({ name: SETTINGS_ROUTE });
          this.isSidebarOpen = false;
        })

        this.SidebarButton($r('app.media.lucide_info'), 'About & licenses', (): void => {
          this.showAboutSheet = true;
          this.isSidebarOpen = false;
        })
      }
      .width(316)
      .height('100%')
      .padding({ left: 18, right: 18, top: 56, bottom: 18 })
      .backgroundColor($r('app.color.surface_background'))

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

        Text('A local HarmonyOS DeepSeek V4 chat client. Third-party notices for bundled runtime assets are listed below.')
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
        this.OpenSourceLibraryBlock(
          'Lucide',
          'latest',
          'ISC',
          'Interface icons used across chat, settings, message actions and the built-in browser.',
          'https://lucide.dev/'
        )
      }
      .width('100%')

      Text('Bundled files are stored under resources/rawfile. Full license texts are included for markdown-it, KaTeX and Lucide.')
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
      'Lucide\n' +
      'License: ISC\n' +
      'Website: https://lucide.dev/\n' +
      'Usage: Interface icons used across chat, settings, message actions and the built-in browser.\n\n' +
      'Bundled license files:\n' +
      'resources/rawfile/markdown/LICENSE-markdown-it.txt\n' +
      'resources/rawfile/markdown/LICENSE-katex.txt\n' +
      'resources/rawfile/LICENSE-lucide.txt';
  }

}
