import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ModelMode, getDeepSeekModelId } from '../main/ets/models/ApiModels';
import { MessageRole, createConversationTitle, createMessage } from '../main/ets/models/ChatModels';
import { normalizeSearchResults } from '../main/ets/models/SearchModels';
import { mapDeepSeekError, parseSseChunk } from '../main/ets/services/DeepSeekSseParser';

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
  });
}
