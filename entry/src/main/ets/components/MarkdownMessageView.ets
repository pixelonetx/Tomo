import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { buildMarkdownHtml, estimateMarkdownHeight } from '../shared/MarkdownHtmlRenderer';

@Component
export struct MarkdownMessageView {
  @Prop @Watch('onContentChanged') content: string;
  @Prop @Watch('onFontSizeChanged') fontSize: number;
  private controller: webview.WebviewController = new webview.WebviewController();
  private isControllerAttached: boolean = false;

  onContentChanged(): void {
    this.loadMarkdown();
  }

  onFontSizeChanged(): void {
    this.loadMarkdown();
  }

  build() {
    Web({ src: '', controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .backgroundColor(Color.Transparent)
      .height(estimateMarkdownHeight(this.content, this.fontSize))
      .width('100%')
      .onControllerAttached((): void => {
        this.isControllerAttached = true;
        this.loadMarkdown();
      })
  }

  private loadMarkdown(): void {
    if (!this.isControllerAttached) {
      return;
    }
    try {
      this.controller.loadData(
        buildMarkdownHtml(this.content, this.fontSize),
        'text/html',
        'UTF-8',
        ' ',
        ' '
      );
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Markdown render failed. code=${error.code}, message=${error.message}`);
    }
  }
}
