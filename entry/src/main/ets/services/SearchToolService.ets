import { ApiToolDefinition } from '../models/ApiModels';
import {
  SearchFreshness,
  SearchOptions,
  SearchResult,
  ToolCallRecord,
  normalizeSearchResults
} from '../models/SearchModels';

export const WEB_SEARCH_TOOL_NAME: string = 'web_search';

export interface WebSearchArguments {
  query: string;
  freshness: string;
}

export interface ParsedWebSearchArguments {
  ok: boolean;
  arguments: WebSearchArguments;
  errorMessage: string;
}

export interface SearchProvider {
  search(query: string, options: SearchOptions): Promise<SearchResult[]>;
}

interface SearchToolResultItem {
  index: number;
  title: string;
  url: string;
  snippet: string;
  published_at: string;
  source: string;
}

interface SearchToolResultPayload {
  query: string;
  results: SearchToolResultItem[];
}

interface FailedToolResultPayload {
  error: string;
  message: string;
}

export class SearchService {
  private provider: SearchProvider | null = null;

  setProvider(provider: SearchProvider): void {
    this.provider = provider;
  }

  async search(query: string, options: SearchOptions): Promise<SearchResult[]> {
    if (this.provider === null) {
      return [];
    }
    const results: SearchResult[] = await this.provider.search(query, options);
    return normalizeSearchResults(results, options.maxResults);
  }
}

export function createWebSearchToolDefinition(): ApiToolDefinition {
  return {
    type: 'function',
    function: {
      name: WEB_SEARCH_TOOL_NAME,
      description: 'Search the web for current or factual information. Use it when the user asks for latest, current, recent, source-backed, or web-verifiable information.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'The search query.'
          },
          freshness: {
            type: 'string',
            enum: [SearchFreshness.ANY, SearchFreshness.DAY, SearchFreshness.WEEK, SearchFreshness.MONTH],
            description: 'Optional freshness preference.'
          }
        },
        required: ['query', 'freshness'],
        additionalProperties: false
      }
    }
  };
}

export function parseWebSearchArguments(argumentsJson: string): ParsedWebSearchArguments {
  const empty: WebSearchArguments = {
    query: '',
    freshness: SearchFreshness.ANY
  };
  try {
    const root = JSON.parse(argumentsJson) as Record<string, Object>;
    const query: string = stringField(root, 'query').trim();
    const freshness: string = normalizeFreshness(stringField(root, 'freshness'));
    if (query.length === 0) {
      return {
        ok: false,
        arguments: empty,
        errorMessage: 'Search query is empty.'
      };
    }
    return {
      ok: true,
      arguments: {
        query: query,
        freshness: freshness
      },
      errorMessage: ''
    };
  } catch (_err) {
    return {
      ok: false,
      arguments: empty,
      errorMessage: 'Search arguments are not valid JSON.'
    };
  }
}

export function createSearchToolResultJson(query: string, results: SearchResult[]): string {
  const items: SearchToolResultItem[] = [];
  const normalized: SearchResult[] = normalizeSearchResults(results, 5);
  for (let i = 0; i < normalized.length; i++) {
    const result: SearchResult = normalized[i];
    items.push({
      index: i + 1,
      title: result.title,
      url: result.url,
      snippet: result.snippet,
      published_at: result.publishedAt,
      source: result.source
    });
  }
  const payload: SearchToolResultPayload = {
    query: query,
    results: items
  };
  return JSON.stringify(payload);
}

export function createFailedToolResultJson(code: string, message: string): string {
  const payload: FailedToolResultPayload = {
    error: code,
    message: message
  };
  return JSON.stringify(payload);
}

export function createToolCallRecord(
  messageId: string,
  toolCallId: string,
  name: string,
  argumentsJson: string,
  resultJson: string,
  status: string
): ToolCallRecord {
  const now: number = Date.now();
  return {
    id: `tool_${messageId}_${toolCallId}`,
    messageId: messageId,
    toolCallId: toolCallId,
    name: name,
    argumentsJson: argumentsJson,
    resultJson: resultJson,
    status: status,
    createdAt: now
  };
}

function normalizeFreshness(value: string): string {
  if (value === SearchFreshness.DAY || value === SearchFreshness.WEEK || value === SearchFreshness.MONTH) {
    return value;
  }
  return SearchFreshness.ANY;
}

function stringField(source: Record<string, Object>, key: string): string {
  const value = source[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}
