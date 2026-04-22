export enum MarkdownBlockType {
  PARAGRAPH = 'paragraph',
  HEADING = 'heading',
  LIST_ITEM = 'list_item',
  QUOTE = 'quote',
  CODE_BLOCK = 'code_block'
}

export class MarkdownInlineSegment {
  text: string = '';
  isCode: boolean = false;
}

export class MarkdownBlock {
  type: MarkdownBlockType = MarkdownBlockType.PARAGRAPH;
  text: string = '';
  language: string = '';
  level: number = 0;
  segments: MarkdownInlineSegment[] = [];
}

export function parseMarkdown(content: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  const lines: string[] = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  let paragraphLines: string[] = [];
  let codeLines: string[] = [];
  let inCodeBlock: boolean = false;
  let codeLanguage: string = '';

  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i];
    const trimmed: string = line.trim();

    if (trimmed.startsWith('```')) {
      if (inCodeBlock) {
        blocks.push(createCodeBlock(codeLines.join('\n'), codeLanguage));
        codeLines = [];
        codeLanguage = '';
        inCodeBlock = false;
      } else {
        appendParagraph(blocks, paragraphLines);
        paragraphLines = [];
        codeLanguage = trimmed.substring(3).trim();
        inCodeBlock = true;
      }
      continue;
    }

    if (inCodeBlock) {
      codeLines.push(line);
      continue;
    }

    if (trimmed.length === 0) {
      appendParagraph(blocks, paragraphLines);
      paragraphLines = [];
      continue;
    }

    const headingLevel: number = getHeadingLevel(line);
    if (headingLevel > 0) {
      appendParagraph(blocks, paragraphLines);
      paragraphLines = [];
      blocks.push(createTextBlock(MarkdownBlockType.HEADING, line.substring(headingLevel + 1).trim(), headingLevel));
      continue;
    }

    const listText: string = getListText(line);
    if (listText.length > 0) {
      appendParagraph(blocks, paragraphLines);
      paragraphLines = [];
      blocks.push(createTextBlock(MarkdownBlockType.LIST_ITEM, listText, 0));
      continue;
    }

    if (trimmed.startsWith('> ')) {
      appendParagraph(blocks, paragraphLines);
      paragraphLines = [];
      blocks.push(createTextBlock(MarkdownBlockType.QUOTE, trimmed.substring(2).trim(), 0));
      continue;
    }

    paragraphLines.push(trimmed);
  }

  if (inCodeBlock) {
    blocks.push(createCodeBlock(codeLines.join('\n'), codeLanguage));
  }
  appendParagraph(blocks, paragraphLines);

  if (blocks.length === 0 && content.length > 0) {
    blocks.push(createTextBlock(MarkdownBlockType.PARAGRAPH, content, 0));
  }
  return blocks;
}

export function parseInlineMarkdown(text: string): MarkdownInlineSegment[] {
  const segments: MarkdownInlineSegment[] = [];
  let cursor: number = 0;
  while (cursor < text.length) {
    const start: number = text.indexOf('`', cursor);
    if (start < 0) {
      pushInlineText(segments, text.substring(cursor), false);
      break;
    }
    if (start > cursor) {
      pushInlineText(segments, text.substring(cursor, start), false);
    }
    const end: number = text.indexOf('`', start + 1);
    if (end < 0) {
      pushInlineText(segments, text.substring(start), false);
      break;
    }
    pushInlineText(segments, text.substring(start + 1, end), true);
    cursor = end + 1;
  }
  return segments;
}

function appendParagraph(blocks: MarkdownBlock[], lines: string[]): void {
  if (lines.length === 0) {
    return;
  }
  blocks.push(createTextBlock(MarkdownBlockType.PARAGRAPH, lines.join(' '), 0));
}

function createTextBlock(type: MarkdownBlockType, text: string, level: number): MarkdownBlock {
  const block = new MarkdownBlock();
  block.type = type;
  block.text = text;
  block.level = level;
  block.segments = parseInlineMarkdown(text);
  return block;
}

function createCodeBlock(text: string, language: string): MarkdownBlock {
  const block = new MarkdownBlock();
  block.type = MarkdownBlockType.CODE_BLOCK;
  block.text = text;
  block.language = language;
  return block;
}

function pushInlineText(segments: MarkdownInlineSegment[], text: string, isCode: boolean): void {
  if (text.length === 0) {
    return;
  }
  const segment = new MarkdownInlineSegment();
  segment.text = normalizeLinkText(text);
  segment.isCode = isCode;
  segments.push(segment);
}

function normalizeLinkText(text: string): string {
  let result: string = text;
  let start: number = result.indexOf('[');
  while (start >= 0) {
    const endLabel: number = result.indexOf('](', start);
    if (endLabel < 0) {
      break;
    }
    const endUrl: number = result.indexOf(')', endLabel + 2);
    if (endUrl < 0) {
      break;
    }
    const label: string = result.substring(start + 1, endLabel);
    const url: string = result.substring(endLabel + 2, endUrl);
    result = result.substring(0, start) + label + ' (' + url + ')' + result.substring(endUrl + 1);
    start = result.indexOf('[', start + label.length + url.length + 3);
  }
  return result;
}

function getHeadingLevel(line: string): number {
  let level: number = 0;
  while (level < line.length && line.charAt(level) === '#') {
    level++;
  }
  if (level > 0 && level <= 6 && line.length > level && line.charAt(level) === ' ') {
    return level;
  }
  return 0;
}

function getListText(line: string): string {
  const trimmed: string = line.trim();
  if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
    return trimmed.substring(2).trim();
  }
  const dotIndex: number = trimmed.indexOf('.');
  if (dotIndex <= 0 || dotIndex + 1 >= trimmed.length || trimmed.charAt(dotIndex + 1) !== ' ') {
    return '';
  }
  for (let i = 0; i < dotIndex; i++) {
    const code: number = trimmed.charCodeAt(i);
    if (code < 48 || code > 57) {
      return '';
    }
  }
  return trimmed.substring(dotIndex + 2).trim();
}
