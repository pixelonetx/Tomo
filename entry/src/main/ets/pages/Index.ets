import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { APP_NAME, CONTEXT_EXTENDED_CHAR_BUDGET, CONTEXT_STANDARD_CHAR_BUDGET } from '../shared/Constants';
import { MarkdownMessageView } from '../components/MarkdownMessageView';
import { ModelMode } from '../models/ApiModels';
import { ChatMessage, Conversation, MessageRole, SendStatus } from '../models/ChatModels';
import { SearchResult } from '../models/SearchModels';
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
      this.SettingsDestination();
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
          this.vm.deleteMessage(message.id);
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
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('API Keys')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('Stored locally as HUKS AES-GCM encrypted payloads. Legacy Preferences keys are migrated on startup. DeepSeek powers chat; Tavily powers web search.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
      .width('100%')

      Text('DeepSeek')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
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

      Text('Tavily Search')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      TextInput({ placeholder: 'tvly-...', text: this.vm.searchApiKeyDraft })
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
          this.vm.searchApiKeyDraft = value;
        })

      Row({ space: 10 }) {
        Button('Clear search')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.vm.clearSearchApiKey();
          })

        Button('Check search')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.vm.checkSearchApiKey();
          })

        Button('Save search')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(10)
          .onClick((): void => {
            this.vm.saveSearchApiKey(this.vm.searchApiKeyDraft);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private SettingsDestination() {
    NavDestination() {
      List({ space: 14 }) {
        ListItem() {
          this.SettingsSectionTitle('Model')
        }
        ListItem() {
          Row({ space: 10 }) {
            Button('Chat')
              .layoutWeight(1)
              .height(40)
              .fontColor(this.vm.modelMode === ModelMode.CHAT ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(this.vm.modelMode === ModelMode.CHAT ? $r('app.color.button_primary') : Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setModelMode(ModelMode.CHAT);
              })
            Button('Reasoner')
              .layoutWeight(1)
              .height(40)
              .fontColor(this.vm.modelMode === ModelMode.REASONER ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(this.vm.modelMode === ModelMode.REASONER ? $r('app.color.button_primary') : Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setModelMode(ModelMode.REASONER);
              })
          }
          .width('100%')
        }

        ListItem() {
          this.SettingsSectionTitle('Reading')
        }
        ListItem() {
          Row({ space: 10 }) {
            Button('-')
              .width(44)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setFontSize(this.vm.fontSize - 1);
              })
            Text(`Font ${this.vm.fontSize}`)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
            Button('+')
              .width(44)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setFontSize(this.vm.fontSize + 1);
              })
          }
          .width('100%')
        }

        ListItem() {
          this.SettingsSectionTitle('Context')
        }
        ListItem() {
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Button('Standard 128K')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor(this.vm.getContextWindowText() === 'Standard 128K' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
                .backgroundColor(this.vm.getContextWindowText() === 'Standard 128K' ? $r('app.color.button_primary') : Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.setContextWindowChars(CONTEXT_STANDARD_CHAR_BUDGET);
                })
              Button('1M-ready')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor(this.vm.getContextWindowText() === 'Extended 1M-ready' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
                .backgroundColor(this.vm.getContextWindowText() === 'Extended 1M-ready' ? $r('app.color.button_primary') : Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.setContextWindowChars(CONTEXT_EXTENDED_CHAR_BUDGET);
                })
            }
            .width('100%')
            Text(this.vm.getContextUsageText())
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(19)
              .width('100%')
          }
          .width('100%')
        }

        ListItem() {
          this.SettingsSectionTitle('Web Search')
        }
        ListItem() {
          Row({ space: 10 }) {
            Button(this.vm.webSearchEnabled ? 'Default On' : 'Default Off')
              .layoutWeight(1)
              .height(40)
              .fontColor(this.vm.webSearchEnabled ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(this.vm.webSearchEnabled ? $r('app.color.button_primary') : Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setWebSearchDefault(!this.vm.webSearchEnabled);
              })
            Button('-')
              .width(44)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setSearchMaxResults(this.vm.getSearchMaxResults() - 1);
              })
            Text(`Max ${this.vm.getSearchMaxResults()}`)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .width(64)
            Button('+')
              .width(44)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.vm.setSearchMaxResults(this.vm.getSearchMaxResults() + 1);
              })
          }
          .width('100%')
        }

        ListItem() {
          this.SettingsSectionTitle('API Keys')
        }
        ListItem() {
          this.ApiKeySheetContent()
        }

        ListItem() {
          this.SettingsSectionTitle('Account')
        }
        ListItem() {
          Column({ space: 10 }) {
            Text(this.vm.getProviderStatusText())
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Row({ space: 10 }) {
              Button('Check balance')
                .layoutWeight(1)
                .height(40)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.vm.checkBalance();
                })
              Button('Copy status')
                .layoutWeight(1)
                .height(40)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.copyText(this.vm.getProviderStatusText());
                })
            }
            .width('100%')
            if (this.vm.balanceMessage.length > 0) {
              Text(this.vm.balanceMessage)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(19)
                .width('100%')
            }
          }
          .width('100%')
        }

        ListItem() {
          this.SettingsSectionTitle('Data')
        }
        ListItem() {
          Column({ space: 10 }) {
            Text(this.vm.getConversationCountText())
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Row({ space: 10 }) {
              Button('Export Markdown')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.exportCurrentConversation('markdown');
                })
              Button('Export JSON')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.exportCurrentConversation('json');
                })
            }
            .width('100%')
            Row({ space: 10 }) {
              Button('Clear chats')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.showDangerConfirm('chats');
                })
              Button('Clear settings')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(8)
                .onClick((): void => {
                  this.showDangerConfirm('settings');
                })
            }
            .width('100%')
            if (this.vm.settingsMessage.length > 0) {
              Text(this.vm.settingsMessage)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(19)
                .width('100%')
            }
          }
          .width('100%')
        }

        ListItem() {
          Button('About & licenses')
            .width('100%')
            .height(42)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              this.showAboutSheet = true;
            })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 22 })
      .backgroundColor($r('app.color.page_background'))
    }
    .title('Settings')
    .hideTitleBar(false)
  }

  @Builder
  private SettingsSectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
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
    Column({ space: 16 }) {
      Text(this.getDangerConfirmTitle())
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.getDangerConfirmMessage())
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(19)
        .width('100%')

      Row({ space: 10 }) {
        Button('Cancel')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.showDangerConfirmSheet = false;
            this.pendingDangerAction = '';
          })

        Button(this.getDangerConfirmActionText())
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(10)
          .onClick((): void => {
            this.runDangerAction();
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
      this.DetailRow('Sources', this.getSelectedMessageSourceCount())
      if (this.getSelectedMessageSourceCount() !== '0') {
        this.SourceList()
      }

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
  private EditMessageSheetContent() {
    Column({ space: 16 }) {
      Text('Edit message')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      TextArea({ placeholder: 'Message', text: this.editMessageDraft })
        .fontSize(this.vm.fontSize)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_placeholder'))
        .backgroundColor($r('app.color.input_bar_background'))
        .border({ width: 1, color: $r('app.color.input_border') })
        .borderRadius(10)
        .height(168)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onChange((value: string): void => {
          this.editMessageDraft = value;
        })

      Row({ space: 10 }) {
        Button('Cancel')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick((): void => {
            this.showEditMessageSheet = false;
          })

        Button('Save & regenerate')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.button_primary'))
          .borderRadius(10)
          .onClick((): void => {
            this.vm.editUserMessageAndRegenerate(this.selectedMessageId, this.editMessageDraft);
            this.showEditMessageSheet = false;
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
    this.showDangerConfirmSheet = true;
  }

  private getDangerConfirmTitle(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Clear settings';
    }
    return 'Clear chats';
  }

  private getDangerConfirmMessage(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Reset local settings and remove encrypted DeepSeek and Tavily keys?';
    }
    return 'Delete all local conversations on this device?';
  }

  private getDangerConfirmActionText(): string {
    if (this.pendingDangerAction === 'settings') {
      return 'Clear settings';
    }
    return 'Clear chats';
  }

  private runDangerAction(): void {
    const action: string = this.pendingDangerAction;
    this.showDangerConfirmSheet = false;
    this.pendingDangerAction = '';
    if (action === 'settings') {
      this.vm.resetLocalSettingsAndKeys();
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

  @Builder
  private SourceList() {
      Column({ space: 10 }) {
      ForEach(this.getSelectedMessageSources(), (source: SearchResult, index: number) => {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Button(`[${source.index > 0 ? source.index : index + 1}] ${source.title}`)
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.showMessageDetailSheet = false;
                this.openWebLink(source.url, source.title);
              })

            Button('Copy')
              .width(72)
              .height(40)
              .fontSize(12)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                this.copyText(source.url);
              })
          }
          .width('100%')

          Text(source.source.length > 0 ? source.source : this.getHostFromUrl(source.url))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (source.snippet.length > 0) {
            Text(source.snippet)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .padding(10)
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(8)
      }, (source: SearchResult): string => source.url)
    }
    .width('100%')
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

  private getSelectedMessageSourceCount(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return '0';
    }
    return `${message.searchSources.length}`;
  }

  private getSelectedMessageSources(): SearchResult[] {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null) {
      return [];
    }
    return message.searchSources;
  }

  private getSelectedMessageSourcesText(): string {
    const message: ChatMessage | null = this.getSelectedMessage();
    if (message === null || message.searchSources.length === 0) {
      return '';
    }
    let text: string = '';
    for (let i = 0; i < message.searchSources.length; i++) {
      const source = message.searchSources[i];
      const index: number = source.index > 0 ? source.index : i + 1;
      text += `[${index}] ${source.title}\n${source.url}`;
      if (source.snippet.length > 0) {
        text += `\n${source.snippet}`;
      }
      if (i < message.searchSources.length - 1) {
        text += '\n\n';
      }
    }
    return text;
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
      `Cache hit / miss: ${this.getSelectedMessageCacheTokens()}\n` +
      `Sources: ${this.getSelectedMessageSourceCount()}\n\n` +
      this.getSelectedMessageSourcesText();
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

  private getHostFromUrl(url: string): string {
    const noProtocol: string = url.replace(/^https?:\/\//i, '');
    const slashIndex: number = noProtocol.indexOf('/');
    if (slashIndex < 0) {
      return noProtocol;
    }
    return noProtocol.substring(0, slashIndex);
  }
}
