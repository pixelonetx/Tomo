import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ApiMessage, ApiToolDefinition, ModelMode, getDeepSeekModelId } from '../main/ets/models/ApiModels';
import { MessageRole, createConversationTitle, createMessage } from '../main/ets/models/ChatModels';
import { createDefaultSettings } from '../main/ets/models/SettingsModels';
import { SearchResult, normalizeSearchResults } from '../main/ets/models/SearchModels';
import { DeepSeekService, parseBalanceResponse, parseChatCompletionResponse, parseModelListResponse } from '../main/ets/services/DeepSeekService';
import { mapDeepSeekError, parseSseChunk } from '../main/ets/services/DeepSeekSseParser';
import { getDisplayUrl, normalizeWebUrl } from '../main/ets/services/BrowserService';
import {
  WEB_SEARCH_TOOL_NAME,
  createFailedToolResultJson,
  createSearchToolResultJson,
  createToolCallRecord,
  createWebSearchToolDefinition,
  parseWebSearchArguments
} from '../main/ets/services/SearchToolService';
import { buildMarkdownHtml, estimateMarkdownHeight, normalizeTaskListMarkers, toScriptString } from '../main/ets/shared/MarkdownHtmlRenderer';

export default function localUnitTest() {
  describe('deepSeekClientFoundation', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });

    it('maps model modes to DeepSeek model ids', 0, () => {
      expect(getDeepSeekModelId(ModelMode.CHAT)).assertEqual('deepseek-chat');
      expect(getDeepSeekModelId(ModelMode.REASONER)).assertEqual('deepseek-reasoner');
    });

    it('builds chat and reasoner request bodies', 0, () => {
      const service = new DeepSeekService();
      const messages: ApiMessage[] = [{ role: 'assistant', content: 'done', reasoningContent: 'hidden' }];
      const chatBody = service.buildRequestBody(messages, ModelMode.CHAT);
      const reasonerBody = service.buildRequestBody(messages, ModelMode.REASONER);
      expect(chatBody.model).assertEqual('deepseek-chat');
      expect(chatBody.temperature).assertEqual(1.0);
      expect(chatBody.messages[0].reasoning_content).assertEqual('hidden');
      expect(reasonerBody.model).assertEqual('deepseek-reasoner');
      expect(reasonerBody.messages[0].reasoning_content).assertUndefined();
    });

    it('builds DeepSeek web_search tool schema and tool request body', 0, () => {
      const service = new DeepSeekService();
      const tool: ApiToolDefinition = createWebSearchToolDefinition();
      const requestBody = service.buildToolRequestBody([{ role: 'user', content: 'latest DeepSeek API changes' }], ModelMode.CHAT, [tool]);
      expect(tool.function.name).assertEqual(WEB_SEARCH_TOOL_NAME);
      expect(JSON.stringify(tool.function.parameters).indexOf('"additionalProperties":false') >= 0).assertTrue();
      expect(requestBody.stream).assertFalse();
      expect(requestBody.tool_choice).assertEqual('auto');
      expect(requestBody.tools?.length).assertEqual(1);
    });

    it('creates bounded conversation titles', 0, () => {
      expect(createConversationTitle('  hello    DeepSeek  ')).assertEqual('hello DeepSeek');
      expect(createConversationTitle('')).assertEqual('New chat');
      expect(createConversationTitle('abcdefghijklmnopqrstuvwxyz0123456789').length).assertEqual(28);
    });

    it('creates local chat messages with expected role and content', 0, () => {
      const message = createMessage('conv_1', MessageRole.USER, 'hello');
      expect(message.conversationId).assertEqual('conv_1');
      expect(message.role).assertEqual(MessageRole.USER);
      expect(message.content).assertEqual('hello');
    });

    it('loads conservative default settings', 0, () => {
      const settings = createDefaultSettings();
      expect(settings.modelMode).assertEqual(ModelMode.CHAT);
      expect(settings.fontSize).assertEqual(15);
      expect(settings.backgroundEnabled).assertFalse();
      expect(settings.webSearchDefaultEnabled).assertFalse();
      expect(settings.searchMaxResults).assertEqual(5);
    });

    it('parses DeepSeek stream content and reasoning chunks', 0, () => {
      const payload = 'data: {"id":"chatcmpl-1","created":1,"model":"deepseek-reasoner","system_fingerprint":"fp","choices":[{"delta":{"content":"answer","reasoning_content":"think"},"finish_reason":"stop"}]}\n\n';
      const deltas = parseSseChunk(payload);
      expect(deltas.length).assertEqual(1);
      expect(deltas[0].content).assertEqual('answer');
      expect(deltas[0].reasoningContent).assertEqual('think');
      expect(deltas[0].finishReason).assertEqual('stop');
      expect(deltas[0].metadata?.model).assertEqual('deepseek-reasoner');
    });

    it('parses DeepSeek usage and cache tokens', 0, () => {
      const payload = 'data: {"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":6,"total_tokens":16,"completion_tokens_details":{"reasoning_tokens":3},"prompt_tokens_details":{"cached_tokens":4}}}\n\n';
      const deltas = parseSseChunk(payload);
      expect(deltas.length).assertEqual(1);
      expect(deltas[0].usage?.promptTokens).assertEqual(10);
      expect(deltas[0].usage?.completionTokens).assertEqual(6);
      expect(deltas[0].usage?.reasoningTokens).assertEqual(3);
      expect(deltas[0].usage?.cacheHitTokens).assertEqual(4);
      expect(deltas[0].usage?.cacheMissTokens).assertEqual(6);
    });

    it('marks done stream events', 0, () => {
      const deltas = parseSseChunk(': keep-alive\n\ndata: [DONE]\n\n');
      expect(deltas.length).assertEqual(1);
      expect(deltas[0].done).assertTrue();
    });

    it('deduplicates and limits search results', 0, () => {
      const results = normalizeSearchResults([
        { title: 'A', url: 'https://example.com/a', snippet: 'alpha', publishedAt: '', source: 'x' },
        { title: 'A again', url: 'https://example.com/a', snippet: 'duplicate', publishedAt: '', source: 'x' },
        { title: '', url: 'https://example.com/empty-title', snippet: 'empty title', publishedAt: '', source: 'x' },
        { title: 'B', url: 'https://example.com/b', snippet: 'beta', publishedAt: '', source: 'x' }
      ], 5);
      expect(results.length).assertEqual(2);
      expect(results[0].title).assertEqual('A');
      expect(results[1].url).assertEqual('https://example.com/b');
    });

    it('maps DeepSeek http errors to user-facing copy', 0, () => {
      expect(mapDeepSeekError(401, '')).assertEqual('API Key 无效，请检查密钥。');
      expect(mapDeepSeekError(429, '')).assertEqual('请求过于频繁，请稍后重试。');
      expect(mapDeepSeekError(503, '')).assertEqual('DeepSeek 服务异常，请稍后重试。');
      expect(mapDeepSeekError(400, 'bad request')).assertEqual('bad request');
    });

    it('parses model list response', 0, () => {
      const response = parseModelListResponse('{"object":"list","data":[{"id":"deepseek-chat","object":"model","owned_by":"deepseek"},{"id":"deepseek-reasoner","object":"model","owned_by":"deepseek"}]}');
      expect(response?.object).assertEqual('list');
      expect(response?.data.length).assertEqual(2);
      expect(response?.data[1].id).assertEqual('deepseek-reasoner');
    });

    it('parses balance response shape', 0, () => {
      const response = parseBalanceResponse('{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"1.00","granted_balance":"0.00","topped_up_balance":"1.00"}]}');
      expect(response?.isAvailable).assertTrue();
      expect(response?.balanceInfos.length).assertEqual(1);
      expect(response?.balanceInfos[0].currency).assertEqual('CNY');
    });

    it('parses non-streaming DeepSeek tool call response', 0, () => {
      const response = parseChatCompletionResponse('{"id":"chatcmpl-tool","created":2,"model":"deepseek-chat","choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":"","tool_calls":[{"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{\\\"query\\\":\\\"DeepSeek API\\\",\\\"freshness\\\":\\\"week\\\"}"}}]}}],"usage":{"prompt_tokens":5,"completion_tokens":7,"total_tokens":12}}');
      expect(response?.metadata.finishReason).assertEqual('tool_calls');
      expect(response?.toolCalls.length).assertEqual(1);
      expect(response?.toolCalls[0].function.name).assertEqual('web_search');
      expect(response?.usage.totalTokens).assertEqual(12);
    });

    it('validates web_search arguments and builds compact tool messages', 0, () => {
      const parsed = parseWebSearchArguments('{"query":" DeepSeek API latest ","freshness":"day"}');
      expect(parsed.ok).assertTrue();
      expect(parsed.arguments.query).assertEqual('DeepSeek API latest');
      expect(parseWebSearchArguments('{bad json').ok).assertFalse();
      expect(parseWebSearchArguments('{"query":"","freshness":"year"}').ok).assertFalse();

      const results: SearchResult[] = [
        { title: 'Docs', url: 'https://api-docs.deepseek.com/', snippet: 'DeepSeek API docs', publishedAt: '', source: 'DeepSeek' }
      ];
      const resultJson: string = createSearchToolResultJson(parsed.arguments.query, results);
      expect(resultJson.indexOf('"results"') >= 0).assertTrue();
      expect(resultJson.indexOf('"index":1') >= 0).assertTrue();
      expect(createFailedToolResultJson('search_failed', 'no provider').indexOf('search_failed') >= 0).assertTrue();
      expect(createToolCallRecord('msg_1', 'call_1', 'web_search', '{}', resultJson, 'success').messageId).assertEqual('msg_1');
    });

    it('builds markdown html with local renderer assets and math support', 0, () => {
      const html = buildMarkdownHtml('# Title\n\n$$E=mc^2$$\n\n```ts\nlet a = 1;\n```', 15);
      expect(html.indexOf('markdown-it.min.js') >= 0).assertTrue();
      expect(html.indexOf('katex.min.js') >= 0).assertTrue();
      expect(html.indexOf('auto-render.min.js') >= 0).assertTrue();
      expect(html.indexOf('renderMathInElement') >= 0).assertTrue();
      expect(html.indexOf('copy-code') >= 0).assertTrue();
      expect(html.indexOf('markdownBridge.updateMarkdownHeight') >= 0).assertTrue();
      expect(html.indexOf('markdownBridge.openLink') >= 0).assertTrue();
      expect(html.indexOf('closest("a[href]")') >= 0).assertTrue();
      expect(html.indexOf('ResizeObserver') >= 0).assertTrue();
      expect(html.indexOf('MutationObserver') >= 0).assertTrue();
    });

    it('accepts only http links for browser navigation', 0, () => {
      expect(normalizeWebUrl(' https://example.com/a ')).assertEqual('https://example.com/a');
      expect(normalizeWebUrl('http://example.com/a')).assertEqual('http://example.com/a');
      expect(normalizeWebUrl('file:///data/a')).assertEqual('');
      expect(getDisplayUrl('https://example.com/a')).assertEqual('example.com/a');
    });

    it('normalizes markdown task list markers and protects script data', 0, () => {
      expect(normalizeTaskListMarkers('- [x] done\n- [ ] todo')).assertEqual('- ☑ done\n- ☐ todo');
      expect(toScriptString('</script><p>x</p>').indexOf('<\\/script') >= 0).assertTrue();
      expect(estimateMarkdownHeight('text\n```ts\ncode\n```', 15) > 40).assertTrue();
    });
  });
}
