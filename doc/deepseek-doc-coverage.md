# DeepSeek 中文文档覆盖清单

本文记录已经阅读过的 DeepSeek 中文官方文档页面，以及应用是否采用其中能力。

结论优先：

- 当前实现依据以中文站为准。
- 第一版只做 DeepSeek Chat / Reasoner、联网搜索、模型诊断、余额查询、usage 统计。
- 联网搜索采用 DeepSeek Tool Calls，但只开放内置 `web_search`，不做任意工具执行平台。
- 思考模式支持 Tool Calls，Reasoner 搜索直接使用 `deepseek-reasoner`。
- Beta 能力只记录，不默认进入第一版主线。

## 快速开始

| 页面 | 结论 | 项目处理 |
| --- | --- | --- |
| 首次调用 API | DeepSeek API 兼容 OpenAI Chat Completions，base URL 可用 `https://api.deepseek.com`。 | 采用。DeepSeekService 使用该 base URL。 |
| 模型 & 价格 | `deepseek-chat` / `deepseek-reasoner` 均为 V3.2，128K 上下文；价格按缓存命中、缓存未命中、输出分别计费。 | 采用。存 usage 和 cache token；价格只用于可选估算，不硬编码为业务逻辑。 |
| Temperature 设置 | 不同场景建议不同温度；思考模式不支持 temperature/top_p 等参数。 | 第一版只保留默认值；高级参数后置。 |
| Token 用量计算 | 可以离线估算 token；实际 billing 以 API usage 为准。 | 优先使用返回 usage；离线估算不进第一版。 |
| 限速 | 当前没有固定账号并发上限，但可能因系统负载出现动态 429/503。 | UI 做 429/503 清晰提示；保留重试。 |
| 错误码 | 400/401/402/422/429/500/503 各有原因。 | 映射到用户可读错误文案。 |

## API 文档

| 页面 | 结论 | 项目处理 |
| --- | --- | --- |
| 基本信息 | 使用 Bearer API Key 认证。 | API Key 不进日志，不进文档，不进错误信息。 |
| 对话补全 | 支持 system/user/assistant/tool message，支持 `thinking`、`tools`、`tool_choice`、`response_format`、stream、usage。 | 采用核心字段；普通聊天默认 stream；搜索使用 tool message。 |
| 列出模型 | `/models` 返回可用模型列表。 | 设置页提供模型可用性检查。 |
| 查询余额 | `/user/balance` 返回账户余额结构。 | 设置页手动查询；不写入聊天消息；不记录具体余额日志。 |

## API 指南

| 页面 | 结论 | 项目处理 |
| --- | --- | --- |
| 思考模式 | 可用 `deepseek-reasoner` 或 `thinking.enabled`；输出 `reasoning_content` 和 `content`；支持 Tool Calls、JSON Output、对话前缀续写；不支持 FIM。 | 主路径用 `deepseek-reasoner`；保留 `thinking.enabled` 兼容入口；Reasoning 默认折叠。 |
| 多轮对话 | 下一轮历史应传最终回答，不传上一回合思维链。 | 普通新用户回合清理上一回合 `reasoning_content`。 |
| 对话前缀续写 Beta | 需要 `/beta`，可强制 assistant 前缀；reasoner 下还有 prefix reasoning 输入规则。 | 不进第一版。仅记录为未来高级能力。 |
| FIM 补全 Beta | 只支持 `deepseek-chat`，偏代码补全场景。 | 不采用。应用不是代码代理。 |
| JSON Output | 可要求输出 JSON，但需要提示词明确写 JSON，且要处理空白/截断风险。 | 不做用户功能；未来可用于会话标题/结构化摘要。 |
| Tool Calls | 支持非思考和思考模式；strict Beta 可约束 JSON Schema；模型本身不执行工具。 | 联网搜索采用 Tool Calls；只开放内置 `web_search`。 |
| 上下文硬盘缓存 | 默认启用，重复前缀命中缓存；usage 返回命中/未命中 token。 | 不自建缓存；稳定 prompt 和历史格式；展示 cache token。 |
| Anthropic API | 可通过 Anthropic 兼容接口接入其它客户端。 | 不采用。第一版只接 Chat Completions。 |

## FAQ

| 主题 | 结论 | 项目处理 |
| --- | --- | --- |
| 并发和限流 | 没有固定提高并发套餐；高负载时可能动态 429/503。 | 错误提示和重试，不承诺并发能力。 |
| API 默认非流式 | API 默认 `stream=false`，网页端默认流式。 | App 明确设置 `stream=true`。 |
| 空行 / keep-alive | 等待调度时可能持续返回空行或 SSE `: keep-alive`。 | SSE 解析器必须忽略空行和 keep-alive。 |
| 分 Key 用量 | 平台账单可导出用量明细。 | App 不做分 Key 财务报表，只做本地 usage 粗略统计。 |
| 余额和充值 | 余额、发票、退款等在平台处理。 | App 只提供余额查询入口和平台跳转。 |

## 更新日志和新闻

| 页面 | 当前意义 | 项目处理 |
| --- | --- | --- |
| 2025-12-01 DeepSeek-V3.2 正式版 | 当前最重要依据：V3.2、思考融入工具调用、Speciale 临时 API。 | 采用 V3.2 规则；不接 Speciale。 |
| 2025-09-29 DeepSeek-V3.2-Exp | DSA、降价、实验版历史。 | 只作为历史，不写进第一版逻辑。 |
| 2025-09-22 DeepSeek V3.1 更新 | 语言一致性、搜索能力优化。 | 历史参考。 |
| 2025-08-21 DeepSeek-V3.1 发布 | 混合推理架构、工具使用能力增强。 | 背景参考，当前以 V3.2 为准。 |
| 2025-05-28 DeepSeek-R1-0528 | R1 更新，Function Calling / JSON Output 能力历史。 | 历史参考。 |
| 2025-03-25 DeepSeek-V3-0324 | V3 模型能力提升。 | 历史参考。 |
| 2025-01-20 DeepSeek-R1 | R1 发布与定价历史。 | 历史参考。 |
| 2025-01-15 DeepSeek APP | DeepSeek App 发布。 | 不影响 API 客户端实现。 |
| 2024-12-26 DeepSeek-V3 | V3 发布和价格历史。 | 历史参考。 |
| 2024-12-10 V2.5-1210 | 官网联网搜索上线。 | 产品方向参考，但 App 采用 API Tool Calls 自建搜索。 |
| 2024-11-20 R1-Lite | 推理预览版历史。 | 历史参考。 |
| 2024-09-05 V2.5 | 通用与代码能力融合历史。 | 历史参考。 |
| 2024-08-02 API 上线硬盘缓存 | 缓存机制来源。 | 采用 cache token 展示和稳定前缀策略。 |
| 2024-07-25 API 升级新功能 | 续写、FIM、Function Calling、JSON Output 上线历史。 | 当前只采用 Tool Calls；其他 Beta 能力暂不做。 |

## 其它资源

| 页面 | 结论 | 项目处理 |
| --- | --- | --- |
| 实用集成 GitHub | 面向各种框架集成。 | 不作为第一版依赖。 |
| API 服务状态 | 可查看服务状态。 | 设置页/错误页可提供外部链接。 |

## 第一版能力取舍

采用：

- Chat / Reasoner。
- Streaming。
- Reasoning 展示。
- Tool Calls 搜索。
- Model list。
- Balance。
- Usage / cache token。
- 错误码映射。
- keep-alive 处理。

暂不采用：

- FIM。
- 对话前缀续写。
- Anthropic API。
- strict Beta 默认启用。
- JSON Output 用户功能。
- DeepSeek-V3.2-Speciale。

明确不做：

- 任意工具执行平台。
- 代码执行代理。
