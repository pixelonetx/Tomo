import { ModelMode } from '../models/ApiModels';
import { CONTEXT_EXTENDED_CHAR_BUDGET, CONTEXT_STANDARD_CHAR_BUDGET } from '../shared/Constants';
import { ChatViewModel } from '../viewmodels/ChatViewModel';

@Builder
export function ApiKeySettingsPanel(
  vm: ChatViewModel,
  onDeepSeekSaved: () => void = (): void => {
  },
  onSearchSaved: () => void = (): void => {
  }
) {
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

    TextInput({ placeholder: 'sk-...', text: vm.apiKeyDraft })
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
        vm.apiKeyDraft = value;
      })

    if (vm.settingsMessage.length > 0) {
      Text(vm.settingsMessage)
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
          vm.clearApiKey();
        })

      Button('Check')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(10)
        .onClick((): void => {
          vm.checkApiKey();
        })

      Button('Save')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          vm.saveApiKey(vm.apiKeyDraft);
          onDeepSeekSaved();
        })
    }
    .width('100%')

    Text('Tavily Search')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')

    TextInput({ placeholder: 'tvly-...', text: vm.searchApiKeyDraft })
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
        vm.searchApiKeyDraft = value;
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
          vm.clearSearchApiKey();
        })

      Button('Check search')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(10)
        .onClick((): void => {
          vm.checkSearchApiKey();
        })

      Button('Save search')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          vm.saveSearchApiKey(vm.searchApiKeyDraft);
          onSearchSaved();
        })
    }
    .width('100%')
  }
  .width('100%')
  .padding({ left: 20, right: 20, top: 22, bottom: 24 })
  .backgroundColor($r('app.color.page_background'))
}

@Builder
export function SettingsView(
  vm: ChatViewModel,
  onCopyText: (text: string) => void,
  onExportConversation: (format: string) => void,
  onShowDangerConfirm: (action: string) => void,
  onShowAbout: () => void
) {
  NavDestination() {
    List({ space: 14 }) {
      ListItem() {
        SectionTitle('Model')
      }
      ListItem() {
        Row({ space: 10 }) {
          Button('Chat')
            .layoutWeight(1)
            .height(40)
            .fontColor(vm.modelMode === ModelMode.CHAT ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
            .backgroundColor(vm.modelMode === ModelMode.CHAT ? $r('app.color.button_primary') : Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setModelMode(ModelMode.CHAT);
            })
          Button('Reasoner')
            .layoutWeight(1)
            .height(40)
            .fontColor(vm.modelMode === ModelMode.REASONER ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
            .backgroundColor(vm.modelMode === ModelMode.REASONER ? $r('app.color.button_primary') : Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setModelMode(ModelMode.REASONER);
            })
        }
        .width('100%')
      }

      ListItem() {
        SectionTitle('Reading')
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
              vm.setFontSize(vm.fontSize - 1);
            })
          Text(`Font ${vm.fontSize}`)
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
              vm.setFontSize(vm.fontSize + 1);
            })
        }
        .width('100%')
      }

      ListItem() {
        SectionTitle('Context')
      }
      ListItem() {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Button('Standard 128K')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(vm.getContextWindowText() === 'Standard 128K' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(vm.getContextWindowText() === 'Standard 128K' ? $r('app.color.button_primary') : Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                vm.setContextWindowChars(CONTEXT_STANDARD_CHAR_BUDGET);
              })
            Button('1M-ready')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(vm.getContextWindowText() === 'Extended 1M-ready' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(vm.getContextWindowText() === 'Extended 1M-ready' ? $r('app.color.button_primary') : Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                vm.setContextWindowChars(CONTEXT_EXTENDED_CHAR_BUDGET);
              })
          }
          .width('100%')
          Text(vm.getContextUsageText())
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(19)
            .width('100%')
        }
        .width('100%')
      }

      ListItem() {
        SectionTitle('Web Search')
      }
      ListItem() {
        Row({ space: 10 }) {
          Button(vm.webSearchEnabled ? 'Default On' : 'Default Off')
            .layoutWeight(1)
            .height(40)
            .fontColor(vm.webSearchEnabled ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
            .backgroundColor(vm.webSearchEnabled ? $r('app.color.button_primary') : Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setWebSearchDefault(!vm.webSearchEnabled);
            })
          Button('-')
            .width(44)
            .height(40)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setSearchMaxResults(vm.getSearchMaxResults() - 1);
            })
          Text(`Max ${vm.getSearchMaxResults()}`)
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
              vm.setSearchMaxResults(vm.getSearchMaxResults() + 1);
            })
        }
        .width('100%')
      }

      ListItem() {
        SectionTitle('API Keys')
      }
      ListItem() {
        ApiKeySettingsPanel(vm)
      }

      ListItem() {
        SectionTitle('Account')
      }
      ListItem() {
        Column({ space: 10 }) {
          Text(vm.getProviderStatusText())
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
                vm.checkBalance();
              })
            Button('Copy status')
              .layoutWeight(1)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                onCopyText(vm.getProviderStatusText());
              })
          }
          .width('100%')
          if (vm.balanceMessage.length > 0) {
            Text(vm.balanceMessage)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(19)
              .width('100%')
          }
        }
        .width('100%')
      }

      ListItem() {
        SectionTitle('Data')
      }
      ListItem() {
        Column({ space: 10 }) {
          Text(vm.getConversationCountText())
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
                onExportConversation('markdown');
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
                onExportConversation('json');
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
                onShowDangerConfirm('chats');
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
                onShowDangerConfirm('settings');
              })
          }
          .width('100%')
          if (vm.settingsMessage.length > 0) {
            Text(vm.settingsMessage)
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
            onShowAbout();
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
function SectionTitle(title: string) {
  Text(title)
    .fontSize(13)
    .fontWeight(FontWeight.Medium)
    .fontColor($r('app.color.text_secondary'))
    .width('100%')
}
