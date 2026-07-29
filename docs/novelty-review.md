# 生态查重报告

项目：MoonRobots Gate

检查日期：2026 年 7 月 29 日

## 结论

在可见的 MoonBit 包和公开活动项目中，没有发现覆盖源位置解析、可解释决策、策略语义检查与差异、站点地图策略冲突和确定性抓取规划的 Robots Exclusion Protocol 策略工程工具。

这一结论是带记录的公开搜索结果，并不构成“私有、未索引、已废弃或刚发布的仓库一定不存在”的绝对证明。

## 活动要求与历史作品页检查

本次 8 月黑客松将 4,000 至 10,000 行有效 MoonBit 代码作为参考范围，并重点关注真实可用性、清晰边界、工程结构、文档、可执行测试、示例、长期维护和生态价值。报名和材料提交以飞书问卷及后续官方通知为准。

以下较早的 MoonBit 公开活动页面只用于历史生态查重：

- https://www.moonbitlang.cn/2026-scc/
- https://www.moonbitlang.com/2026-scc

检查的历史公开作品页如下：

- https://www.moonbitlang.cn/2026-scc/showcase/

该页面包含 30 个公开项目，涉及文档转换、定理证明、Shell、图表编辑、ORM、解析框架、视觉小说、工业通信、动画、RISC-V 分析、GUI 绑定、智能体编排、SEO 落地页、RAG、量化回测、工作流平台、三维工具、数据库和编辑器等方向，其中没有 Robots 协议或爬虫策略治理项目。该历史页面不代表本次 8 月黑客松的日程或提交通知。

## Mooncakes 检查

检查当日，Mooncakes 显示共有 1,738 个模块。使用的搜索词包括：

- `robots`
- `robots.txt`
- `robotstxt`
- `crawler`
- `crawl-delay`
- `sitemap`
- `SEO`

可见结果中没有发现专用 Robots 协议包。较早的选题调研发现了 `xingwangzhe/license_checker`，因此最初的 SPDX 方向在扩展前就被放弃。

## GitHub 检查

搜索时将 MoonBit 与以下内容组合：

- `robots.txt parser`
- `"User-agent" "Disallow"`
- `crawl-delay`
- `crawler sitemap robots.txt`
- `moon.mod robots.txt`
- `moon.pkg User-agent`

可见结果中没有出现专门覆盖本项目范围的 MoonBit 实现。

## 相邻项目

### MoonSEO

公开作品页将 MoonSEO 描述为一个 MoonBit MVP：它将品牌简报转换为可审计的 SEO 落地页，并导出静态 HTML。

MoonRobots Gate 与它的区别如下：

- 输入：协议文本和站点地图，而不是品牌简报。
- 核心：RFC 风格匹配和策略分析，而不是内容生成。
- 输出：访问决策、诊断、策略差异、矩阵和抓取计划，而不是落地页。
- 用户：爬虫和基础设施开发者，而不是页面作者。

两个项目可以互补，但不能相互替代。

### 通用爬虫

其他语言中的库会解析 `robots.txt`，成熟爬虫也通常在内部包含类似行为。这种领域先例是正常且有参考价值的。本项目的原创性主张专门针对 MoonBit 原生、可复用的策略工程工具，以及源位置诊断、策略差异、站点地图冲突和确定性规划的组合。

## 标准依据

实现参考以下公开标准和文档：

- RFC 9309，Robots Exclusion Protocol：
  https://www.rfc-editor.org/rfc/rfc9309.html
- Google 爬虫基础设施文档：
  https://developers.google.com/crawling/docs/robots-txt/robots-txt-spec
- RFC 3986，URI Generic Syntax：
  https://www.rfc-editor.org/rfc/rfc3986

项目没有复制第三方源码，而是根据公开协议行为独立完成 MoonBit 实现。

## 身份隔离

GitHub 和 Mooncakes 均已独立核对为账号 `2111950632`，参赛者为石子硕。本地仓库尚未配置远端。项目没有复用前两位参赛者的身份、仓库地址或申报文字。
