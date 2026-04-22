import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { normalizeWebUrl } from '../services/BrowserService';
import { buildMarkdownHtml, estimateMarkdownHeight } from '../shared/MarkdownHtmlRenderer';

@Component
export struct MarkdownMessageView {
  @Prop @Watch('onContentChanged') content: string;
  @Prop @Watch('onFontSizeChanged') fontSize: number;
  onOpenLink: (url: string, title: string) => void = (_url: string, _title: string): void => {
  };
  @State renderedHeight: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  private isControllerAttached: boolean = false;

  onContentChanged(): void {
    this.renderedHeight = estimateMarkdownHeight(this.content, this.fontSize);
    this.loadMarkdown();
  }

  onFontSizeChanged(): void {
    this.renderedHeight = estimateMarkdownHeight(this.content, this.fontSize);
    this.loadMarkdown();
  }

  build() {
    Web({ src: '', controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .backgroundColor(Color.Transparent)
      .height(this.renderedHeight > 0 ? this.renderedHeight : estimateMarkdownHeight(this.content, this.fontSize))
      .width('100%')
      .onControllerAttached((): void => {
        this.isControllerAttached = true;
        this.registerHeightBridge();
        this.renderedHeight = estimateMarkdownHeight(this.content, this.fontSize);
        this.loadMarkdown();
      })
  }

  updateMarkdownHeight(heightText: string): void {
    const height: number = Number.parseInt(heightText);
    if (Number.isNaN(height)) {
      return;
    }
    const nextHeight: number = Math.min(Math.max(height + 2, 48), 8000);
    if (Math.abs(nextHeight - this.renderedHeight) >= 2) {
      this.renderedHeight = nextHeight;
    }
  }

  openLink(urlText: string, titleText: string): void {
    const url: string = normalizeWebUrl(urlText);
    if (url.length === 0) {
      return;
    }
    this.onOpenLink(url, titleText.trim());
  }

  private registerHeightBridge(): void {
    try {
      this.controller.registerJavaScriptProxy(this, 'markdownBridge', ['updateMarkdownHeight', 'openLink']);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Markdown height bridge registration failed. code=${error.code}, message=${error.message}`);
    }
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
