export interface SearchOptions {
  maxResults: number;
  locale: string;
  freshness: string;
}

export enum SearchFreshness {
  ANY = 'any',
  DAY = 'day',
  WEEK = 'week',
  MONTH = 'month'
}

export interface SearchResult {
  title: string;
  url: string;
  snippet: string;
  publishedAt: string;
  source: string;
}

export interface ToolCallRecord {
  id: string;
  messageId: string;
  toolCallId: string;
  name: string;
  argumentsJson: string;
  resultJson: string;
  status: string;
  createdAt: number;
}

export interface SearchToolRunResult {
  content: string;
  reasoningContent: string;
  sources: SearchResult[];
  toolCalls: ToolCallRecord[];
  finishReason: string;
  errorMessage: string;
}

export function normalizeSearchResults(results: SearchResult[], maxResults: number): SearchResult[] {
  const seen: string[] = [];
  const normalized: SearchResult[] = [];
  const limit: number = Math.min(Math.max(maxResults, 0), 5);

  for (let i = 0; i < results.length && normalized.length < limit; i++) {
    const item: SearchResult = results[i];
    const title: string = item.title.trim();
    const url: string = item.url.trim();
    if (title.length === 0 || url.length === 0 || seen.indexOf(url) >= 0) {
      continue;
    }
    seen.push(url);
    normalized.push({
      title: title,
      url: url,
      snippet: truncateSnippet(item.snippet),
      publishedAt: item.publishedAt,
      source: item.source.trim()
    });
  }

  return normalized;
}

function truncateSnippet(snippet: string): string {
  const maxLength: number = 280;
  const cleanSnippet: string = snippet.trim();
  if (cleanSnippet.length <= maxLength) {
    return cleanSnippet;
  }
  return cleanSnippet.substring(0, maxLength);
}
