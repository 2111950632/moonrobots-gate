# MoonRobots Gate

MoonRobots Gate 是一套使用 MoonBit 实现的 Robots Exclusion Protocol 策略工程工具。它可以解析并规范化 `robots.txt`、解释访问判断、审计策略质量、比较策略版本、校验站点地图交互，并在明确的预算约束下生成确定性抓取计划。

本项目面向爬虫开发者、文档索引器、链接检查器、静态站点工具、CI 流程和 AI 智能体，使它们无须引入完整爬虫框架，也能获得可复现的策略判断。

## 当前状态

- MoonBit 核心库代码 4,284 行。
- MoonBit 测试代码 1,213 行。
- 共 102 项测试，覆盖解析、匹配、URL 处理、语义检查、渲染、策略差异、访问矩阵、站点地图、抓取规划和审计报告。
- 除 `moonbitlang/core` 外没有其他运行时依赖。
- `moon check`、`moon build`、`moon test` 和 `moon package --list` 均已通过。
- GitHub 与 Mooncakes 命名空间均已独立核对为 `2111950632`。

## 主要能力

### 协议解析

- 解析 `User-agent`、`Allow` 和 `Disallow` 指令。
- 保存 `Sitemap`、`Crawl-delay`、`Host`、`Clean-param` 和未知扩展，同时避免扩展指令破坏标准分组。
- 处理注释、CRLF、UTF-8 BOM、空记录、重复值、格式错误和防御式输入限制。
- 生成带稳定代码、严重程度、行号、问题说明和修复建议的源位置诊断。

### 访问判断

- 选择匹配度最高的产品令牌。
- 合并所有同等匹配度的用户代理组。
- 使用最长路径匹配规则，并在同等长度下由 `Allow` 胜出。
- 支持 `*`、末尾 `$`、区分大小写的路径，以及对未保留字符百分号编码的 RFC 风格归一化。
- 对 `/robots.txt` 提供隐式允许。
- 返回完整决策轨迹，而不只是布尔值。

### 策略工程

- 语义检查器可发现全站阻断、缺少兜底组、重复和冲突规则、无效百分号转义、错误的 `$` 位置、冗余通配符、异常抓取延迟、查询字符串敏感规则和非标准指令。
- 提供规范化、紧凑化和带源位置注释的渲染结果。
- 支持用户代理组、规则、站点地图、主机和抓取延迟的结构差异比较。
- 支持基于调用方探针的行为差异比较。
- 支持 Markdown 和 CSV 访问矩阵。

### 站点地图与抓取规划

- 解析 XML `urlset`、XML `sitemapindex` 和纯文本站点地图。
- 校验绝对 URL、重复地址、日期前缀、优先级、更新频率和跨域条目。
- 报告被指定爬虫策略阻止的站点地图 URL。
- 将站点地图条目转换为带优先级的抓取任务。
- 按请求数、字节数、深度、单主机配额、Robots 规则、重复 URL 和抓取延迟约束规划任务。
- 输出顺序稳定的已接受任务和被拒绝任务报告。

### 审计报告

- 在一次操作中完成解析、语义检查和可配置访问矩阵。
- 生成有上限的风险分数和等级。
- 为人工审阅输出 Markdown，为 CI 或智能体输出稳定 JSON。

## 安装

```bash
moon add 2111950632/robots-gate
```

包命名空间已通过 `moon whoami` 核对为 `2111950632`。

## 库使用示例

```moonbit
let policy = @robots_gate.parse(
  #|User-agent: *
  #|Disallow: /private/
  #|Allow: /private/public/
  #|Crawl-delay: 2
)

let decision = @robots_gate.decide(
  policy,
  "ExampleBot/1.0",
  "/private/public/index.html",
)

println(decision.summary())
println(@robots_gate.render_decision_trace(decision))
```

运行完整审计：

```moonbit
let audit = @robots_gate.audit(
  robots_text,
  ["Googlebot", "Bingbot", "GPTBot"],
  ["/", "/admin/", "/api/", "/private/", "/public/"],
)

println(@robots_gate.render_audit_markdown(audit))
```

校验站点地图并生成抓取计划：

```moonbit
let sitemap = @robots_gate.parse_sitemap(sitemap_text)
let tasks = @robots_gate.tasks_from_sitemap(sitemap, 32768)
let budget = @robots_gate.crawl_budget(100, 10000000, 8, 25, 1000)
let plan = @robots_gate.plan_crawl(policy, "ExampleBot", tasks, budget)

println(@robots_gate.render_crawl_plan(plan))
```

## 命令行工具

CLI 默认使用内置策略和站点地图。可以通过 `MOONROBOTS_POLICY` 或 `MOONROBOTS_SITEMAP` 提供自定义内容，无须增加文件系统或网络依赖。

```powershell
moon run cmd/main -- decide ExampleBot /private/report
moon run cmd/main -- lint
moon run cmd/main -- normalize
moon run cmd/main -- matrix
moon run cmd/main -- sitemap
moon run cmd/main -- plan
moon run cmd/main -- diff
moon run cmd/main -- audit
moon run cmd/main -- audit json
moon run cmd/main -- stats
```

使用自定义输入的 PowerShell 示例：

```powershell
$env:MOONROBOTS_POLICY = @"
User-agent: *
Disallow: /internal/
Allow: /internal/public/
Sitemap: https://example.com/sitemap.xml
"@

moon run cmd/main -- audit
```

## 可运行示例

```powershell
moon run examples/basic
moon run examples/advanced
moon run examples/sitemap
moon run examples/planner
```

## 架构

| 模块 | 职责 |
| --- | --- |
| `model.mbt` | 公共协议类型、诊断类型、决策类型和统计类型 |
| `parser.mbt` | 防御式逐行解析和源位置诊断 |
| `matcher.mbt` | 用户代理选择、通配符匹配和决策轨迹 |
| `url.mbt` | HTTP URL 解析及来源、路径辅助函数 |
| `lint.mbt` | 语义和可维护性诊断 |
| `render.mbt` | 策略、诊断、轨迹和摘要输出 |
| `matrix.mbt` | 批量探针和行为比较 |
| `diff.mbt` | 结构变化和探针驱动的行为变化 |
| `sitemap.mbt` | 站点地图解析、校验和策略过滤 |
| `frontier.mbt` | 带预算约束的确定性抓取规划 |
| `audit.mbt` | 聚合评分以及 Markdown、JSON 报告 |

模块边界和数据流详见[架构文档](docs/architecture.md)。

## 标准定位

匹配模型遵循 [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html) 的核心规则，包括产品令牌选择、最长路径匹配、同等匹配下的 `Allow` 优先、区分大小写的路径、百分号编码处理，以及对 `/robots.txt` 的隐式访问。

`Sitemap`、`Crawl-delay`、`Host` 和 `Clean-param` 属于扩展指令，而不是 RFC 9309 的规范记录。MoonRobots Gate 会保存并报告这些指令，同时让扩展解析与标准分组边界保持独立。

## 范围与非目标

`0.2.0` 版本是协议与规划核心，明确不负责以下工作：

- 获取远程资源或跟随重定向。
- 执行 DNS、TLS、HTTP 缓存或内容解码。
- 实际执行抓取或持久化分布式任务队列。
- 实现通用 XML 解析器。
- 宣称与所有搜索引擎扩展逐字节兼容。

调用方负责网络传输和持久化。这样的边界使核心库可以移植到不同 MoonBit 目标，并保证策略行为在测试、CI 和 WebAssembly 应用中保持确定。

## 生态查重

选题检查范围包括：

- 较早一次 MoonBit 公开活动展示的 30 个项目，该页面仅作为历史生态查重来源。
- Mooncakes 中与 `robots`、`robots.txt`、爬虫、站点地图和 SEO 有关的搜索。
- GitHub 中将 MoonBit 与 `robots.txt`、`User-agent`、`Crawl-delay`、爬虫和站点地图组合的搜索。

公开结果中未发现专门面向 Robots 协议策略工程和抓取治理的 MoonBit 包或展示项目。相邻项目 MoonSEO 用于生成和审计 SEO 落地页，并不解析 `robots.txt`、判断爬虫访问权限、校验站点地图与策略冲突，也不规划受策略约束的抓取任务。

详细且带日期的搜索记录见[生态查重报告](docs/novelty-review.md)。

## 开发

```powershell
moon info
moon fmt
moon check
moon build
moon test
moon package --list
```

CI 会在推送和拉取请求中运行同一套验证流程。

## 文档

- [架构说明](docs/architecture.md)
- [生态查重报告](docs/novelty-review.md)
- [开发复盘](docs/development-retrospective.md)
- [项目申报书](docs/submission-application.md)
- [提交检查清单](docs/submission-checklist.md)

## 许可证

Apache-2.0。
