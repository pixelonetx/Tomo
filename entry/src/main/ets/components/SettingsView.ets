import { ModelMode } from '../models/ApiModels';
import { CONTEXT_EXTENDED_CHAR_BUDGET, CONTEXT_STANDARD_CHAR_BUDGET } from '../shared/Constants';
import { ChatViewModel } from '../viewmodels/ChatViewModel';

@Builder
function SettingsIconButton(icon: Resource, label: string, action: () => void, primary: boolean = false) {
  Row({ space: 7 }) {
    Image(icon)
      .width(15)
      .height(15)
      .objectFit(ImageFit.Contain)
    Text(label)
      .fontSize(13)
      .fontColor(primary ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
  .layoutWeight(1)
  .height(42)
  .padding({ left: 10, right: 10 })
  .justifyContent(FlexAlign.Center)
  .backgroundColor(primary ? $r('app.color.button_primary') : $r('app.color.surface_background'))
  .border({ width: primary ? 0 : 1, color: $r('app.color.divider') })
  .borderRadius(10)
  .onClick(action)
}

@Builder
function SettingsWideIconButton(icon: Resource, label: string, action: () => void) {
  Row({ space: 8 }) {
    Image(icon)
      .width(16)
      .height(16)
      .objectFit(ImageFit.Contain)
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
  }
  .width('100%')
  .height(42)
  .padding({ left: 12, right: 12 })
  .backgroundColor($r('app.color.surface_background'))
  .border({ width: 1, color: $r('app.color.divider') })
  .borderRadius(8)
  .onClick(action)
}

@Builder
export function ApiKeySettingsPanel(
  vm: ChatViewModel,
  onDeepSeekSaved: () => void = (): void => {
  },
  onSearchSaved: () => void = (): void => {
  }
) {
  Column({ space: 16 }) {
    Column({ space: 6 }) {
      Text('API Keys')
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
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
      .backgroundColor($r('app.color.surface_background'))
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
      SettingsIconButton($r('app.media.lucide_trash_2'), 'Clear', (): void => {
        vm.clearApiKey();
      })

      SettingsIconButton($r('app.media.lucide_key_round'), 'Check', (): void => {
        vm.checkApiKey();
      })

      SettingsIconButton($r('app.media.lucide_plus_on_primary'), 'Save', (): void => {
        vm.saveApiKey(vm.apiKeyDraft);
        onDeepSeekSaved();
      }, true)
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
      .backgroundColor($r('app.color.surface_background'))
      .border({ width: 1, color: $r('app.color.input_border') })
      .borderRadius(10)
      .height(46)
      .padding({ left: 12, right: 12 })
      .onChange((value: string): void => {
        vm.searchApiKeyDraft = value;
      })

    Row({ space: 10 }) {
      SettingsIconButton($r('app.media.lucide_trash_2'), 'Clear', (): void => {
        vm.clearSearchApiKey();
      })

      SettingsIconButton($r('app.media.lucide_search'), 'Check', (): void => {
        vm.checkSearchApiKey();
      })

      SettingsIconButton($r('app.media.lucide_plus_on_primary'), 'Save', (): void => {
        vm.saveSearchApiKey(vm.searchApiKeyDraft);
        onSearchSaved();
      }, true)
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
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Model')
      }
      ListItem() {
        Row({ space: 10 }) {
          Button('V4 Flash')
            .layoutWeight(1)
            .height(40)
            .fontColor(vm.modelMode === ModelMode.CHAT ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
            .backgroundColor(vm.modelMode === ModelMode.CHAT ? $r('app.color.button_primary') : $r('app.color.surface_background'))
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setModelMode(ModelMode.CHAT);
            })
          Button('V4 Pro')
            .layoutWeight(1)
            .height(40)
            .fontColor(vm.modelMode === ModelMode.REASONER ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
            .backgroundColor(vm.modelMode === ModelMode.REASONER ? $r('app.color.button_primary') : $r('app.color.surface_background'))
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
            .backgroundColor($r('app.color.surface_background'))
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
            .backgroundColor($r('app.color.surface_background'))
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
            Button('Balanced 128K')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(vm.getContextWindowText() === 'Balanced 128K' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(vm.getContextWindowText() === 'Balanced 128K' ? $r('app.color.button_primary') : $r('app.color.surface_background'))
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                vm.setContextWindowChars(CONTEXT_STANDARD_CHAR_BUDGET);
              })
            Button('V4 1M')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(vm.getContextWindowText() === 'V4 1M' ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
              .backgroundColor(vm.getContextWindowText() === 'V4 1M' ? $r('app.color.button_primary') : $r('app.color.surface_background'))
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
            .backgroundColor(vm.webSearchEnabled ? $r('app.color.button_primary') : $r('app.color.surface_background'))
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(8)
            .onClick((): void => {
              vm.setWebSearchDefault(!vm.webSearchEnabled);
            })
          Button('-')
            .width(44)
            .height(40)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_background'))
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
            .backgroundColor($r('app.color.surface_background'))
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
              .backgroundColor($r('app.color.surface_background'))
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .onClick((): void => {
                vm.checkBalance();
              })
            Button('Copy status')
              .layoutWeight(1)
              .height(40)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_background'))
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
              .backgroundColor($r('app.color.surface_background'))
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
              .backgroundColor($r('app.color.surface_background'))
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
              .backgroundColor($r('app.color.surface_background'))
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
              .backgroundColor($r('app.color.surface_background'))
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
        SettingsWideIconButton($r('app.media.lucide_info'), 'About & licenses', (): void => {
          onShowAbout();
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Settings')
  .hideTitleBar(false)
}

@Builder
function SectionTitle(title: string) {
  Text(title)
    .fontSize(13)
    .fontWeight(FontWeight.Regular)
    .fontColor($r('app.color.text_secondary'))
    .width('100%')
}
