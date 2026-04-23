import { ChatMessage } from '../models/ChatModels';
import { SearchResult } from '../models/SearchModels';

@Builder
export function DangerConfirmSheet(
  title: string,
  message: string,
  actionText: string,
  onCancel: () => void,
  onConfirm: () => void
) {
  Column({ space: 16 }) {
    Text(title)
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')

    Text(message)
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
          onCancel();
        })

      Button(actionText)
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          onConfirm();
        })
    }
    .width('100%')
  }
  .width('100%')
  .padding({ left: 20, right: 20, top: 22, bottom: 24 })
  .backgroundColor($r('app.color.page_background'))
}

@Builder
export function EditMessageSheet(
  draft: string,
  fontSize: number,
  onDraftChange: (value: string) => void,
  onCancel: () => void,
  onSave: () => void
) {
  Column({ space: 16 }) {
    Text('Edit message')
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')

    TextArea({ placeholder: 'Message', text: draft })
      .fontSize(fontSize)
      .fontColor($r('app.color.text_primary'))
      .placeholderColor($r('app.color.text_placeholder'))
      .backgroundColor($r('app.color.input_bar_background'))
      .border({ width: 1, color: $r('app.color.input_border') })
      .borderRadius(10)
      .height(168)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onChange((value: string): void => {
        onDraftChange(value);
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
          onCancel();
        })

      Button('Save & regenerate')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          onSave();
        })
    }
    .width('100%')
  }
  .width('100%')
  .padding({ left: 20, right: 20, top: 22, bottom: 24 })
  .backgroundColor($r('app.color.page_background'))
}

@Builder
export function MessageDetailSheet(
  message: ChatMessage | null,
  onCopyText: (text: string) => void,
  onOpenSource: (url: string, title: string) => void,
  onClose: () => void
) {
  Column({ space: 16 }) {
    Text('Message details')
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')

    DetailRow('Role', getRole(message))
    DetailRow('Status', getStatus(message))
    DetailRow('Model', getModel(message))
    DetailRow('Finish reason', getFinishReason(message))
    DetailRow('Response ID', getResponseId(message))
    DetailRow('Prompt tokens', getPromptTokens(message))
    DetailRow('Completion tokens', getCompletionTokens(message))
    DetailRow('Reasoning tokens', getReasoningTokens(message))
    DetailRow('Total tokens', getTotalTokens(message))
    DetailRow('Cache hit / miss', getCacheTokens(message))
    DetailRow('Sources', getSourceCount(message))
    if (getSourceCount(message) !== '0') {
      SourceList(message, onCopyText, onOpenSource, onClose)
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
          onCopyText(getContent(message));
        })

      Button('Copy details')
        .layoutWeight(1)
        .height(42)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.button_primary'))
        .borderRadius(10)
        .onClick((): void => {
          onCopyText(getDetailsText(message));
        })
    }
    .width('100%')
  }
  .width('100%')
  .padding({ left: 20, right: 20, top: 22, bottom: 24 })
  .backgroundColor($r('app.color.page_background'))
}

@Builder
function DetailRow(label: string, value: string) {
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

@Builder
function SourceList(
  message: ChatMessage | null,
  onCopyText: (text: string) => void,
  onOpenSource: (url: string, title: string) => void,
  onClose: () => void
) {
  Column({ space: 10 }) {
    ForEach(getSources(message), (source: SearchResult, index: number) => {
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
              onClose();
              onOpenSource(source.url, source.title);
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
              onCopyText(source.url);
            })
        }
        .width('100%')

        Text(source.source.length > 0 ? source.source : getHostFromUrl(source.url))
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

function getContent(message: ChatMessage | null): string {
  return message === null ? '' : message.content;
}

function getRole(message: ChatMessage | null): string {
  return message === null ? '' : message.role;
}

function getStatus(message: ChatMessage | null): string {
  return message === null ? '' : message.status;
}

function getModel(message: ChatMessage | null): string {
  return message === null ? '' : message.model;
}

function getFinishReason(message: ChatMessage | null): string {
  return message === null ? '' : message.finishReason;
}

function getResponseId(message: ChatMessage | null): string {
  return message === null ? '' : message.responseId;
}

function getPromptTokens(message: ChatMessage | null): string {
  return message === null ? '0' : `${message.promptTokens}`;
}

function getCompletionTokens(message: ChatMessage | null): string {
  return message === null ? '0' : `${message.completionTokens}`;
}

function getReasoningTokens(message: ChatMessage | null): string {
  return message === null ? '0' : `${message.reasoningTokens}`;
}

function getTotalTokens(message: ChatMessage | null): string {
  return message === null ? '0' : `${message.totalTokens}`;
}

function getCacheTokens(message: ChatMessage | null): string {
  return message === null ? '0 / 0' : `${message.cacheHitTokens} / ${message.cacheMissTokens}`;
}

function getSourceCount(message: ChatMessage | null): string {
  return message === null ? '0' : `${message.searchSources.length}`;
}

function getSources(message: ChatMessage | null): SearchResult[] {
  return message === null ? [] : message.searchSources;
}

function getSourcesText(message: ChatMessage | null): string {
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

function getDetailsText(message: ChatMessage | null): string {
  return `Role: ${getRole(message)}\n` +
    `Status: ${getStatus(message)}\n` +
    `Model: ${getModel(message)}\n` +
    `Finish reason: ${getFinishReason(message)}\n` +
    `Response ID: ${getResponseId(message)}\n` +
    `Prompt tokens: ${getPromptTokens(message)}\n` +
    `Completion tokens: ${getCompletionTokens(message)}\n` +
    `Reasoning tokens: ${getReasoningTokens(message)}\n` +
    `Total tokens: ${getTotalTokens(message)}\n` +
    `Cache hit / miss: ${getCacheTokens(message)}\n` +
    `Sources: ${getSourceCount(message)}\n\n` +
    getSourcesText(message);
}

function getHostFromUrl(url: string): string {
  const noProtocol: string = url.replace(/^https?:\/\//i, '');
  const slashIndex: number = noProtocol.indexOf('/');
  if (slashIndex < 0) {
    return noProtocol;
  }
  return noProtocol.substring(0, slashIndex);
}
