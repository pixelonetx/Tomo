import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { ApiToolDefinition } from '../models/ApiModels';
import {
  SearchFreshness,
  SearchOptions,
  SearchResult,
  ToolCallRecord,
  normalizeSearchResults
} from '../models/SearchModels';
import { SEARCH_REQUEST_TIMEOUT, TAVILY_SEARCH_ENDPOINT } from '../shared/Constants';

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
  getLastErrorMessage(): string;
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

interface TavilySearchRequest {
  query: string;
  search_depth: string;
  max_results: number;
  include_answer: boolean;
  include_raw_content: boolean;
  include_images: boolean;
  topic: string;
  time_range?: string;
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

  getLastErrorMessage(): string {
    if (this.provider === null) {
      return 'Search provider is not configured.';
    }
    return this.provider.getLastErrorMessage();
  }
}

export class TavilySearchProvider implements SearchProvider {
  private apiKey: string = '';
  private lastErrorMessage: string = '';

  setApiKey(key: string): void {
    this.apiKey = key.trim();
  }

  async search(query: string, options: SearchOptions): Promise<SearchResult[]> {
    this.lastErrorMessage = '';
    if (this.apiKey.length === 0 || query.trim().length === 0) {
      this.lastErrorMessage = this.apiKey.length === 0 ? 'Search API Key is not configured.' : 'Search query is empty.';
      return [];
    }
    const requestBody: TavilySearchRequest = {
      query: query.trim(),
      search_depth: 'basic',
      max_results: Math.min(Math.max(options.maxResults, 1), 5),
      include_answer: false,
      include_raw_content: false,
      include_images: false,
      topic: 'general'
    };
    const timeRange: string = toTavilyTimeRange(options.freshness);
    if (timeRange.length > 0) {
      requestBody.time_range = timeRange;
    }
    const text: string = await this.requestSearch(JSON.stringify(requestBody));
    if (text.length === 0) {
      return [];
    }
    return parseTavilySearchResponse(text, options.maxResults);
  }

  getLastErrorMessage(): string {
    return this.lastErrorMessage;
  }

  private requestSearch(body: string): Promise<string> {
    const request = http.createHttp();
    return new Promise<string>((resolve) => {
      request.request(
        TAVILY_SEARCH_ENDPOINT,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`
          },
          extraData: body,
          readTimeout: SEARCH_REQUEST_TIMEOUT,
          connectTimeout: SEARCH_REQUEST_TIMEOUT
        },
        (err: BusinessError, data: http.HttpResponse) => {
          request.destroy();
          if (err) {
            this.lastErrorMessage = 'Search network request failed.';
            resolve('');
            return;
          }
          if (data.responseCode === 401 || data.responseCode === 403) {
            this.lastErrorMessage = 'Search API Key is invalid.';
            resolve('');
            return;
          }
          if (data.responseCode === 429) {
            this.lastErrorMessage = 'Search provider rate limit reached.';
            resolve('');
            return;
          }
          if (data.responseCode >= 400) {
            this.lastErrorMessage = 'Search provider request failed.';
            resolve('');
            return;
          }
          if (typeof data.result === 'string') {
            resolve(data.result);
            return;
          }
          resolve(JSON.stringify(data.result));
        }
      );
    });
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
      index: result.index > 0 ? result.index : i + 1,
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

export function parseTavilySearchResponse(text: string, maxResults: number): SearchResult[] {
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const items = root['results'] as Array<Record<string, Object>>;
    const results: SearchResult[] = [];
    if (items !== undefined) {
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        results.push({
          index: 0,
          title: stringField(item, 'title'),
          url: stringField(item, 'url'),
          snippet: firstNonEmptyString(item, 'content', 'snippet'),
          publishedAt: stringField(item, 'published_date'),
          source: sourceFromUrl(stringField(item, 'url'))
        });
      }
    }
    return normalizeSearchResults(results, maxResults);
  } catch (_err) {
    return [];
  }
}

function normalizeFreshness(value: string): string {
  if (value === SearchFreshness.DAY || value === SearchFreshness.WEEK || value === SearchFreshness.MONTH) {
    return value;
  }
  return SearchFreshness.ANY;
}

function toTavilyTimeRange(freshness: string): string {
  if (freshness === SearchFreshness.DAY) {
    return 'day';
  }
  if (freshness === SearchFreshness.WEEK) {
    return 'week';
  }
  if (freshness === SearchFreshness.MONTH) {
    return 'month';
  }
  return '';
}

function firstNonEmptyString(source: Record<string, Object>, firstKey: string, secondKey: string): string {
  const first: string = stringField(source, firstKey);
  if (first.length > 0) {
    return first;
  }
  return stringField(source, secondKey);
}

function sourceFromUrl(url: string): string {
  const withoutProtocol: string = url.replace(/^https?:\/\//i, '');
  const slashIndex: number = withoutProtocol.indexOf('/');
  if (slashIndex < 0) {
    return withoutProtocol;
  }
  return withoutProtocol.substring(0, slashIndex);
}

function stringField(source: Record<string, Object>, key: string): string {
  const value = source[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}
