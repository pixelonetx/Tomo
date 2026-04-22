# HarmonyOS DeepSeek Chat Client 文档

这组文档用于启动一个全新的 HarmonyOS DeepSeek Chat Client。

工程从零开始，只按本文档实现。

## 产品一句话

**一个干净、稳定、轻量、好看的 HarmonyOS DeepSeek 对话客户端。**

## 文档阅读顺序

- `product-spec.md`
  产品目标、非目标、功能范围和体验原则。
- `architecture.md`
  ArkTS 工程结构、状态管理、服务层、数据库、DeepSeek 流式链路。
- `deepseek-api-notes.md`
  DeepSeek 官方 API 要点和本地连通性验证结论。
- `deepseek-doc-coverage.md`
  DeepSeek 中文站逐页阅读后的采用 / 暂缓 / 不采用清单。
- `web-search-design.md`
  联网搜索的产品形态、DeepSeek Tool Calls、来源展示和持久化设计。
- `harmonyos-platform-notes.md`
  HarmonyOS 原生能力落点：Preferences、沉浸式、深浅色、字号、Navigation 和 ArkUI 约束。
- `ui-guidelines.md`
  首页视觉、渐变透明、消息流、输入栏、侧边栏、设置页。
- `home-ui-blueprint.md`
  首页 UI 的 ArkTS 实现蓝图，包含可直接参考的结构和代码片段。
- `implementation-prompt.md`
  给下一位 AI / 开发者的一步到位实现指令。
- `progress.md`
  当前实现进展、验证结果和下一步。

## 总原则

- 先聊天，再联网搜索，再附件。
- 先稳定，再高级。
- 先简洁，再扩展。
- 只做 DeepSeek 对话客户端，不做系统级助手或代码执行代理。
- UI 方向：渐变透明、背景模糊、轻质输入栏。
- 用户首选项使用 HarmonyOS Preferences；会话和消息使用 RDB。
- 不引入与聊天主线无关的复杂抽象。
