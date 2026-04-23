import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ApiMessage, ApiToolDefinition, ModelMode, getDeepSeekModelId } from '../main/ets/models/ApiModels';
import { Conversation, MessageRole, createConversation, createConversationTitle, createMessage } from '../main/ets/models/ChatModels';
import { createDefaultSettings } from '../main/ets/models/SettingsModels';
import { SearchResult, mergeSearchSources, normalizeSearchResults } from '../main/ets/models/SearchModels';
import { DeepSeekService, parseBalanceResponse, parseChatCompletionResponse, parseModelListResponse } from '../main/ets/services/DeepSeekService';
import { mapDeepSeekError, parseSseChunk } from '../main/ets/services/DeepSeekSseParser';
import { getDisplayUrl, normalizeWebUrl } from '../main/ets/services/BrowserService';
import {
  WEB_SEARCH_TOOL_NAME,
  createFailedToolResultJson,
  createSearchToolResultJson,
  createToolCallRecord,
  createWebSearchToolDefinition,
  parseTavilySearchResponse,
  parseWebSearchArguments
} from '../main/ets/services/SearchToolService';
import { buildMarkdownHtml, estimateMarkdownHeight, normalizeTaskListMarkers, toScriptString } from '../main/ets/shared/MarkdownHtmlRenderer';
import { CONTEXT_STANDARD_CHAR_BUDGET } from '../main/ets/shared/Constants';
import { ChatViewModel } from '../main/ets/viewmodels/ChatViewModel';

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
      const streamToolBody = service.buildStreamToolRequestBody([{ role: 'user', content: 'latest DeepSeek API changes' }], ModelMode.CHAT, [tool]);
      expect(streamToolBody.stream).assertTrue();
      expect(streamToolBody.tool_choice).assertEqual('auto');
      expect(streamToolBody.stream_options?.include_usage).assertTrue();
      const finalBody = service.buildToolFinalRequestBody([
        { role: 'assistant', content: '', reasoningContent: 'tool thinking', toolCallsJson: '[{"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{}"}}]' },
        { role: 'tool', content: '{"results":[]}', toolCallId: 'call_1' }
      ], ModelMode.REASONER, [tool]);
      expect(finalBody.stream).assertTrue();
      expect(finalBody.tool_choice).assertEqual('none');
      expect(finalBody.tools?.length).assertEqual(1);
      expect(finalBody.messages[0].reasoning_content).assertEqual('tool thinking');
      expect(finalBody.messages[0].tool_calls?.length).assertEqual(1);
      expect(finalBody.messages[1].tool_call_id).assertEqual('call_1');
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
      expect(settings.contextWindowChars).assertEqual(CONTEXT_STANDARD_CHAR_BUDGET);
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

    it('parses streaming tool call deltas', 0, () => {
      const payload = 'data: {"id":"chatcmpl-tool","created":2,"model":"deepseek-chat","choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{\\\"query\\\":\\\"Deep"}}]},"finish_reason":null}]}\n\n' +
        'data: {"id":"chatcmpl-tool","created":2,"model":"deepseek-chat","choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"Seek API\\\",\\\"freshness\\\":\\\"week\\\"}"}}]},"finish_reason":"tool_calls"}]}\n\n';
      const deltas = parseSseChunk(payload);
      expect(deltas.length).assertEqual(2);
      expect(deltas[0].toolCallDeltas.length).assertEqual(1);
      expect(deltas[0].toolCallDeltas[0].id).assertEqual('call_1');
      expect(deltas[0].toolCallDeltas[0].function.name).assertEqual('web_search');
      expect(deltas[1].toolCallDeltas[0].function.arguments).assertEqual('Seek API","freshness":"week"}');
      expect(deltas[1].finishReason).assertEqual('tool_calls');
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
        { index: 0, title: 'A', url: 'https://example.com/a', snippet: 'alpha', publishedAt: '', source: 'x' },
        { index: 0, title: 'A again', url: 'https://example.com/a', snippet: 'duplicate', publishedAt: '', source: 'x' },
        { index: 0, title: '', url: 'https://example.com/empty-title', snippet: 'empty title', publishedAt: '', source: 'x' },
        { index: 0, title: 'B', url: 'https://example.com/b', snippet: 'beta', publishedAt: '', source: 'x' }
      ], 5);
      expect(results.length).assertEqual(2);
      expect(results[0].title).assertEqual('A');
      expect(results[1].url).assertEqual('https://example.com/b');
    });

    it('merges search sources with stable citation indexes', 0, () => {
      const merged = mergeSearchSources(
        [{ index: 1, title: 'A', url: 'https://example.com/a', snippet: 'alpha', publishedAt: '', source: 'example.com' }],
        [
          { index: 0, title: 'A again', url: 'https://example.com/a', snippet: 'duplicate', publishedAt: '', source: 'example.com' },
          { index: 0, title: 'B', url: 'https://example.com/b', snippet: 'beta', publishedAt: '', source: 'example.com' }
        ]
      );
      expect(merged.length).assertEqual(2);
      expect(merged[0].index).assertEqual(1);
      expect(merged[1].index).assertEqual(2);
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
        { index: 7, title: 'Docs', url: 'https://api-docs.deepseek.com/', snippet: 'DeepSeek API docs', publishedAt: '', source: 'DeepSeek' }
      ];
      const resultJson: string = createSearchToolResultJson(parsed.arguments.query, results);
      expect(resultJson.indexOf('"results"') >= 0).assertTrue();
      expect(resultJson.indexOf('"index":7') >= 0).assertTrue();
      expect(createFailedToolResultJson('search_failed', 'no provider').indexOf('search_failed') >= 0).assertTrue();
      expect(createToolCallRecord('msg_1', 'call_1', 'web_search', '{}', resultJson, 'success').messageId).assertEqual('msg_1');
    });

    it('parses Tavily search results into normalized sources', 0, () => {
      const results = parseTavilySearchResponse('{"results":[{"title":"DeepSeek Docs","url":"https://api-docs.deepseek.com/news","content":"Latest API docs","published_date":"2026-04-01"},{"title":"","url":"https://example.com/empty","content":"skip"}]}', 5);
      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('DeepSeek Docs');
      expect(results[0].snippet).assertEqual('Latest API docs');
      expect(results[0].source).assertEqual('api-docs.deepseek.com');
    });

    it('builds markdown html with local renderer assets and math support', 0, () => {
      const html = buildMarkdownHtml('# Title\n\nSource [1]\n\n$$E=mc^2$$\n\n```ts\nlet a = 1;\n```', 15, [
        { index: 1, title: 'DeepSeek Docs', url: 'https://api-docs.deepseek.com/' }
      ]);
      expect(html.indexOf('markdown-it.min.js') >= 0).assertTrue();
      expect(html.indexOf('katex.min.js') >= 0).assertTrue();
      expect(html.indexOf('auto-render.min.js') >= 0).assertTrue();
      expect(html.indexOf('citationMap') >= 0).assertTrue();
      expect(html.indexOf('data-citation-index') >= 0).assertTrue();
      expect(html.indexOf('markdownBridge.openCitation') >= 0).assertTrue();
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

    it('exports current conversation as markdown and json without secrets', 0, () => {
      const vm = new ChatViewModel();
      const conversation: Conversation = createConversation('Export / Chat');
      const userMessage = createMessage(conversation.id, MessageRole.USER, 'hello');
      const assistantMessage = createMessage(conversation.id, MessageRole.ASSISTANT, 'answer');
      assistantMessage.reasoningContent = 'private chain summary';
      assistantMessage.searchSources = [
        { index: 1, title: 'Docs', url: 'https://api-docs.deepseek.com/', snippet: 'DeepSeek docs', publishedAt: '', source: 'DeepSeek' }
      ];
      conversation.messages = [userMessage, assistantMessage];
      vm.conversations = [conversation];
      vm.currentConversationId = conversation.id;
      vm.messages = conversation.messages;
      const markdown = vm.getCurrentConversationMarkdown();
      expect(markdown.indexOf('# Export / Chat') >= 0).assertTrue();
      expect(markdown.indexOf('## User') >= 0).assertTrue();
      expect(markdown.indexOf('<summary>Reasoning</summary>') >= 0).assertTrue();
      expect(markdown.indexOf('[Docs](https://api-docs.deepseek.com/)') >= 0).assertTrue();
      expect(vm.getCurrentConversationExportName('md')).assertEqual('Export _ Chat.md');
      const json = vm.getCurrentConversationJson();
      expect(json.indexOf('"title": "Export / Chat"') >= 0).assertTrue();
      expect(json.indexOf('sk-') < 0).assertTrue();
    });

    it('shows only active assistant branch versions', 0, () => {
      const vm = new ChatViewModel();
      const conversation: Conversation = createConversation('Branches');
      const userMessage = createMessage(conversation.id, MessageRole.USER, 'draft');
      const firstAssistant = createMessage(conversation.id, MessageRole.ASSISTANT, 'first');
      firstAssistant.branchParentId = userMessage.id;
      firstAssistant.branchIndex = 1;
      firstAssistant.branchActive = false;
      const secondAssistant = createMessage(conversation.id, MessageRole.ASSISTANT, 'second');
      secondAssistant.branchParentId = userMessage.id;
      secondAssistant.branchIndex = 2;
      secondAssistant.branchActive = true;
      conversation.messages = [userMessage, firstAssistant, secondAssistant];
      vm.conversations = [conversation];
      vm.currentConversationId = conversation.id;
      vm.messages = conversation.messages;
      const visible = vm.getVisibleMessages();
      expect(visible.length).assertEqual(2);
      expect(visible[1].content).assertEqual('second');
      expect(vm.getAssistantBranchCount(secondAssistant)).assertEqual(2);
      expect(vm.getAssistantBranchPosition(secondAssistant)).assertEqual(2);
    });

    it('keeps downstream messages scoped to the active branch path', 0, () => {
      const vm = new ChatViewModel();
      const conversation: Conversation = createConversation('Branch path');
      const rootUser = createMessage(conversation.id, MessageRole.USER, 'root');
      const firstAssistant = createMessage(conversation.id, MessageRole.ASSISTANT, 'first');
      firstAssistant.branchParentId = rootUser.id;
      firstAssistant.branchIndex = 1;
      firstAssistant.branchActive = false;
      firstAssistant.pathParentId = rootUser.id;
      const firstFollowUp = createMessage(conversation.id, MessageRole.USER, 'hidden child');
      firstFollowUp.pathParentId = firstAssistant.id;
      const secondAssistant = createMessage(conversation.id, MessageRole.ASSISTANT, 'second');
      secondAssistant.branchParentId = rootUser.id;
      secondAssistant.branchIndex = 2;
      secondAssistant.branchActive = true;
      secondAssistant.pathParentId = rootUser.id;
      const secondFollowUp = createMessage(conversation.id, MessageRole.USER, 'visible child');
      secondFollowUp.pathParentId = secondAssistant.id;
      conversation.messages = [rootUser, firstAssistant, firstFollowUp, secondAssistant, secondFollowUp];
      vm.conversations = [conversation];
      vm.currentConversationId = conversation.id;
      vm.messages = conversation.messages;
      const visible = vm.getVisibleMessages();
      expect(visible.length).assertEqual(3);
      expect(visible[0].content).assertEqual('root');
      expect(visible[1].content).assertEqual('second');
      expect(visible[2].content).assertEqual('visible child');
    });
  });
}
