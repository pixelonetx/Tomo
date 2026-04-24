import { ModelMode } from '../models/ApiModels';
import { ChatViewModel } from '../viewmodels/ChatViewModel';

export const SETTINGS_MODEL_ROUTE: string = 'SettingsModel';
export const SETTINGS_READING_ROUTE: string = 'SettingsReading';
export const SETTINGS_CONTEXT_ROUTE: string = 'SettingsContext';
export const SETTINGS_SEARCH_ROUTE: string = 'SettingsSearch';
export const SETTINGS_KEYS_ROUTE: string = 'SettingsKeys';
export const SETTINGS_ACCOUNT_ROUTE: string = 'SettingsAccount';
export const SETTINGS_DATA_ROUTE: string = 'SettingsData';

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
function SettingsGroupRow(icon: Resource, title: string, detail: string, action: () => void) {
  Row({ space: 12 }) {
    Image(icon)
      .width(18)
      .height(18)
      .objectFit(ImageFit.Contain)
    Column({ space: 3 }) {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(detail)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .layoutWeight(1)
    Image($r('app.media.lucide_chevron_right'))
      .width(15)
      .height(15)
      .objectFit(ImageFit.Contain)
  }
  .width('100%')
  .height(58)
  .padding({ left: 12, right: 12, top: 9, bottom: 9 })
  .backgroundColor($r('app.color.surface_background'))
  .border({ width: 1, color: $r('app.color.divider') })
  .borderRadius(8)
  .onClick(action)
}

@Builder
function SettingsValueRow(label: string, value: string) {
  Row() {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
    Blank()
    Text(value)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .textAlign(TextAlign.End)
      .constraintSize({ maxWidth: '58%' })
  }
  .width('100%')
  .height(42)
  .padding({ left: 12, right: 12 })
  .backgroundColor($r('app.color.surface_background'))
  .border({ width: 1, color: $r('app.color.divider') })
  .borderRadius(8)
}

@Builder
function SettingsStepper(label: string, value: string, onMinus: () => void, onPlus: () => void) {
  Row({ space: 10 }) {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .layoutWeight(1)
    Button('-')
      .width(44)
      .height(40)
      .fontColor($r('app.color.text_primary'))
      .backgroundColor($r('app.color.surface_background'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(8)
      .onClick(onMinus)
    Text(value)
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
      .onClick(onPlus)
  }
  .width('100%')
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
  onOpenSection: (route: string) => void,
  onShowAbout: () => void
) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Chat')
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_settings'), 'Model', vm.modelMode === ModelMode.CHAT ? 'V4 Flash' : 'V4 Pro', (): void => {
          onOpenSection(SETTINGS_MODEL_ROUTE);
        })
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_pencil'), 'Reading', `Font ${vm.fontSize}`, (): void => {
          onOpenSection(SETTINGS_READING_ROUTE);
        })
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_info'), 'Context', vm.getContextWindowText(), (): void => {
          onOpenSection(SETTINGS_CONTEXT_ROUTE);
        })
      }

      ListItem() {
        SectionTitle('Tools')
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_search'), 'Web Search', vm.webSearchEnabled ? `Default on, max ${vm.getSearchMaxResults()}` : `Default off, max ${vm.getSearchMaxResults()}`, (): void => {
          onOpenSection(SETTINGS_SEARCH_ROUTE);
        })
      }

      ListItem() {
        SectionTitle('Keys & Account')
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_key_round'), 'API Keys', vm.getProviderStatusText(), (): void => {
          onOpenSection(SETTINGS_KEYS_ROUTE);
        })
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_info'), 'Account', vm.balanceMessage.length > 0 ? vm.balanceMessage : 'Balance and provider status', (): void => {
          onOpenSection(SETTINGS_ACCOUNT_ROUTE);
        })
      }

      ListItem() {
        SectionTitle('Storage')
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_copy'), 'Data', vm.getConversationCountText(), (): void => {
          onOpenSection(SETTINGS_DATA_ROUTE);
        })
      }
      ListItem() {
        SettingsGroupRow($r('app.media.lucide_info'), 'About & licenses', 'Open source notices', (): void => {
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
export function SettingsModelPage(vm: ChatViewModel) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('DeepSeek model')
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
        Text('V4 Flash is the default chat model. V4 Pro enables thinking mode for harder prompts.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Model')
  .hideTitleBar(false)
}

@Builder
export function SettingsReadingPage(vm: ChatViewModel) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Message text')
      }
      ListItem() {
        SettingsStepper('Font size', `${vm.fontSize}`, (): void => {
          vm.setFontSize(vm.fontSize - 1);
        }, (): void => {
          vm.setFontSize(vm.fontSize + 1);
        })
      }
      ListItem() {
        Text('Main message timestamps stay in Details so the chat stream remains calm and readable.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Reading')
  .hideTitleBar(false)
}

@Builder
export function SettingsContextPage(vm: ChatViewModel) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Window')
      }
      ListItem() {
        SettingsValueRow('Context', vm.getContextWindowText())
      }
      ListItem() {
        Text(vm.getContextUsageText())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Context')
  .hideTitleBar(false)
}

@Builder
export function SettingsSearchPage(vm: ChatViewModel) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Default')
      }
      ListItem() {
        Button(vm.webSearchEnabled ? 'Default On' : 'Default Off')
          .width('100%')
          .height(42)
          .fontColor(vm.webSearchEnabled ? $r('app.color.text_on_primary') : $r('app.color.text_primary'))
          .backgroundColor(vm.webSearchEnabled ? $r('app.color.button_primary') : $r('app.color.surface_background'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(8)
          .onClick((): void => {
            vm.setWebSearchDefault(!vm.webSearchEnabled);
          })
      }
      ListItem() {
        SettingsStepper('Max results', `${vm.getSearchMaxResults()}`, (): void => {
          vm.setSearchMaxResults(vm.getSearchMaxResults() - 1);
        }, (): void => {
          vm.setSearchMaxResults(vm.getSearchMaxResults() + 1);
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Web Search')
  .hideTitleBar(false)
}

@Builder
export function SettingsKeysPage(vm: ChatViewModel) {
  NavDestination() {
    ApiKeySettingsPanel(vm)
  }
  .title('API Keys')
  .hideTitleBar(false)
}

@Builder
export function SettingsAccountPage(vm: ChatViewModel, onCopyText: (text: string) => void) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Provider')
      }
      ListItem() {
        Text(vm.getProviderStatusText())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
      }
      ListItem() {
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
      }
      if (vm.balanceMessage.length > 0) {
        ListItem() {
          Text(vm.balanceMessage)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(19)
            .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Account')
  .hideTitleBar(false)
}

@Builder
export function SettingsDataPage(
  vm: ChatViewModel,
  onExportConversation: (format: string) => void,
  onShowDangerConfirm: (action: string) => void
) {
  NavDestination() {
    List({ space: 12 }) {
      ListItem() {
        SectionTitle('Conversations')
      }
      ListItem() {
        Text(vm.getConversationCountText())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      ListItem() {
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
      }
      ListItem() {
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
      }
      if (vm.settingsMessage.length > 0) {
        ListItem() {
          Text(vm.settingsMessage)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(19)
            .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
  .title('Data')
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
