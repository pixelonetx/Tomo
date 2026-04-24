import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { getDisplayUrl, normalizeWebUrl, openUrlInSystemBrowser } from '../services/BrowserService';

export const WEB_BROWSER_ROUTE: string = 'WebBrowser';

export interface WebBrowserParam {
  url: string;
  title?: string;
}

interface TitleReceiveEvent {
  title: string;
}

interface PageUrlEvent {
  url: string;
}

interface ProgressChangeEvent {
  newProgress: number;
}

interface WebHistoryController {
  accessBackward: () => boolean;
  backward: () => void;
}

@Builder
export function WebBrowserDestinationBuilder() {
  WebBrowserDestination();
}

@Component
export struct WebBrowserDestination {
  private controller: webview.WebviewController = new webview.WebviewController();
  private navPathStack?: NavPathStack;
  @State currentUrl: string = '';
  @State pageTitle: string = 'Browser';
  @State progress: number = 0;
  @State errorMessage: string = '';

  build() {
    NavDestination() {
      Column() {
        if (this.progress > 0 && this.progress < 100) {
          Row()
            .width(`${this.progress}%`)
            .height(2)
            .backgroundColor($r('app.color.button_primary'))
        } else {
          Row()
            .width('100%')
            .height(2)
            .backgroundColor(Color.Transparent)
        }

        Column({ space: 4 }) {
          Text(this.pageTitle)
            .fontSize(15)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(getDisplayUrl(this.currentUrl))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor($r('app.color.surface_background'))
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })

        if (this.errorMessage.length > 0) {
          Column({ space: 12 }) {
            Text(this.errorMessage)
              .fontSize(15)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .lineHeight(22)
              .width('76%')

            Button('Open in browser')
              .height(44)
              .fontColor($r('app.color.text_on_primary'))
              .backgroundColor($r('app.color.button_primary'))
              .borderRadius(10)
              .onClick((): void => {
                this.openExternal();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Web({ src: this.currentUrl, controller: this.controller })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .imageAccess(true)
            .zoomAccess(true)
            .mixedMode(MixedMode.All)
            .cacheMode(CacheMode.Default)
            .onTitleReceive((event): void => {
              const title: string = (event as TitleReceiveEvent).title;
              if (title.trim().length > 0) {
                this.pageTitle = title;
              }
            })
            .onPageBegin((event): void => {
              const url: string = (event as PageUrlEvent).url;
              if (url.trim().length > 0) {
                this.currentUrl = url;
              }
              this.progress = 8;
            })
            .onProgressChange((event): void => {
              const progress: number = (event as ProgressChangeEvent).newProgress;
              this.progress = Math.max(0, Math.min(progress, 100));
            })
            .onPageEnd((_event): void => {
              this.progress = 100;
            })
            .width('100%')
            .layoutWeight(1)
            .backgroundColor($r('app.color.page_background'))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .title(this.pageTitle)
    .menus([
      {
        value: 'Refresh',
        action: (): void => {
          this.refresh();
        }
      },
      {
        value: 'Browser',
        action: (): void => {
          this.openExternal();
        }
      }
    ])
    .hideTitleBar(false)
    .onReady((context: NavDestinationContext): void => {
      this.navPathStack = context.pathStack;
      this.applyParam(context.pathInfo.param as WebBrowserParam);
    })
    .onBackPressed((): boolean => {
      this.goBackOrPop();
      return true;
    })
  }

  private applyParam(param: WebBrowserParam): void {
    if (param === undefined || param === null) {
      this.errorMessage = 'No URL to open.';
      return;
    }
    const url: string = normalizeWebUrl(param.url ?? '');
    if (url.length === 0) {
      this.errorMessage = 'Only http and https links can be opened.';
      this.currentUrl = param.url ?? '';
      return;
    }
    this.currentUrl = url;
    this.errorMessage = '';
    const title: string = param.title ?? '';
    if (title.trim().length > 0) {
      this.pageTitle = title.trim();
    }
  }

  private goBackOrPop(): void {
    try {
      const historyController = this.controller as WebHistoryController;
      if (historyController.accessBackward()) {
        historyController.backward();
        return;
      }
    } catch (_err) {
    }

    this.navPathStack?.pop();
  }

  private refresh(): void {
    if (this.currentUrl.length === 0 || this.errorMessage.length > 0) {
      return;
    }
    try {
      this.controller.loadUrl(this.currentUrl);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Refresh web page failed. code=${error.code}, message=${error.message}`);
    }
  }

  private openExternal(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showToast('Unable to open browser');
      return;
    }
    openUrlInSystemBrowser(context as common.UIAbilityContext, this.currentUrl).then((success: boolean): void => {
      if (!success) {
        this.showToast('Unable to open browser');
      }
    }).catch((_err: Error): void => {
      this.showToast('Unable to open browser');
    });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().openToast({
      message: message,
      duration: 1600
    }).catch((_err: Error): void => {
    });
  }
}
