///|
fn make_span(line : Int, column : Int, length : Int) -> SourceSpan {
  { line, column, length }
}

///|
fn make_diagnostic(
  severity : Severity,
  code : String,
  message : String,
  line : Int,
  hint : String,
) -> Diagnostic {
  { severity, code, message, span: make_span(line, 1, 1), hint }
}

///|
fn make_directive(
  kind : DirectiveKind,
  key : String,
  value : String,
  raw : String,
  line : Int,
) -> Directive {
  { kind, key, value, raw, span: make_span(line, 1, raw.length()) }
}

///|
fn finish_group(
  groups : Array[Group],
  agents : Array[String],
  rules : Array[Rule],
  crawl_delay_millis : Int,
  start_line : Int,
  end_line : Int,
  options : ParseOptions,
  diagnostics : Array[Diagnostic],
) -> Bool {
  if agents.length() == 0 {
    return true
  }
  if groups.length() >= options.max_groups {
    diagnostics.push(
      make_diagnostic(
        Error,
        "RBT013",
        "group limit exceeded; remaining groups were ignored",
        start_line,
        "Split or simplify this robots.txt file.",
      ),
    )
    return false
  }
  groups.push({ agents, rules, crawl_delay_millis, start_line, end_line })
  true
}

///|
/// Parses robots.txt using defensive limits and preserves diagnostics.
pub fn parse_with_options(input : String, options : ParseOptions) -> Policy {
  let groups : Array[Group] = []
  let sitemaps : Array[String] = []
  let hosts : Array[String] = []
  let directives : Array[Directive] = []
  let diagnostics : Array[Diagnostic] = []
  let mut agents : Array[String] = []
  let mut rules : Array[Rule] = []
  let mut crawl_delay_millis = -1
  let mut group_start_line = 0
  let mut group_end_line = 0
  let mut group_has_records = false
  let mut total_rules = 0
  let mut truncated = false
  if input.length() > options.max_input_chars {
    diagnostics.push(
      make_diagnostic(
        Error,
        "RBT001",
        "input exceeds configured character limit",
        1,
        "Raise max_input_chars only for trusted input.",
      ),
    )
    return {
      groups,
      sitemaps,
      hosts,
      directives,
      diagnostics,
      source_lines: 0,
      truncated: true,
    }
  }
  let source_lines = input.split("\n").to_array()
  let mut parsed_lines = source_lines.length()
  if parsed_lines > options.max_lines {
    parsed_lines = options.max_lines
    truncated = true
    diagnostics.push(
      make_diagnostic(
        Error,
        "RBT002",
        "line limit exceeded; remaining lines were ignored",
        options.max_lines,
        "Split the policy or raise max_lines for trusted input.",
      ),
    )
  }
  for index = 0; index < parsed_lines; index = index + 1 {
    let line_no = index + 1
    let raw0 = strip_carriage_return(source_lines[index].to_owned())
    let raw = if index == 0 { strip_utf8_bom(raw0) } else { raw0 }
    if raw.length() > options.max_line_chars {
      diagnostics.push(
        make_diagnostic(
          Error,
          "RBT003",
          "line exceeds configured character limit",
          line_no,
          "Shorten this directive.",
        ),
      )
      continue
    }
    if contains_control_char(raw) {
      diagnostics.push(
        make_diagnostic(
          Warning,
          "RBT004",
          "line contains an ASCII control character",
          line_no,
          "Remove control characters other than horizontal tabs.",
        ),
      )
    }
    let clean = strip_comment(raw).trim().to_owned()
    if clean.length() == 0 {
      continue
    }
    match clean.split_once(":") {
      None =>
        diagnostics.push(
          make_diagnostic(
            Warning,
            "RBT005",
            "record has no colon separator",
            line_no,
            "Use `field: value` syntax.",
          ),
        )
      Some(parts) => {
        let original_key = parts.0.trim().to_owned()
        let key = lower_ascii(original_key)
        let value = parts.1.trim().to_owned()
        let kind = directive_kind(key)
        if options.preserve_unknown || kind != UnknownDirective {
          directives.push(make_directive(kind, key, value, raw, line_no))
        }
        match kind {
          UserAgentDirective => {
            if group_has_records && agents.length() > 0 {
              let added = finish_group(
                groups, agents, rules, crawl_delay_millis, group_start_line, group_end_line,
                options, diagnostics,
              )
              if !added {
                truncated = true
                break
              }
              agents = []
              rules = []
              crawl_delay_millis = -1
              group_start_line = 0
              group_end_line = 0
              group_has_records = false
            }
            if value.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Error,
                  "RBT006",
                  "user-agent value is empty",
                  line_no,
                  "Provide a product token or `*`.",
                ),
              )
            } else {
              let agent = lower_ascii(value)
              if !valid_agent_token(agent) {
                diagnostics.push(
                  make_diagnostic(
                    Warning,
                    "RBT007",
                    "user-agent contains characters outside the portable token set",
                    line_no,
                    "Prefer letters, digits, hyphen, underscore, or dot.",
                  ),
                )
              }
              if array_contains_string(agents, agent) {
                diagnostics.push(
                  make_diagnostic(
                    Info,
                    "RBT008",
                    "duplicate user-agent in the same group",
                    line_no,
                    "Remove the duplicate token.",
                  ),
                )
              } else {
                agents.push(agent)
              }
              if group_start_line == 0 {
                group_start_line = line_no
              }
              group_end_line = line_no
            }
          }
          AllowDirective | DisallowDirective => {
            if agents.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Warning,
                  "RBT009",
                  "path rule before the first user-agent was ignored",
                  line_no,
                  "Move this rule below a User-agent record.",
                ),
              )
              continue
            }
            if total_rules >= options.max_rules {
              diagnostics.push(
                make_diagnostic(
                  Error,
                  "RBT010",
                  "rule limit exceeded; remaining rules were ignored",
                  line_no,
                  "Split or simplify this policy.",
                ),
              )
              truncated = true
              continue
            }
            let rule_kind = if kind == AllowDirective {
              Allow
            } else {
              Disallow
            }
            rules.push({
              kind: rule_kind,
              pattern: value,
              normalized_pattern: normalize_rule_pattern(value),
              line: line_no,
            })
            total_rules = total_rules + 1
            group_has_records = true
            group_end_line = line_no
            if value.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Info,
                  "RBT011",
                  "empty allow or disallow rule has no effect",
                  line_no,
                  "Remove the empty rule for clarity.",
                ),
              )
            }
          }
          SitemapDirective =>
            if value.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Error,
                  "RBT014",
                  "sitemap value is empty",
                  line_no,
                  "Provide an absolute HTTP or HTTPS URL.",
                ),
              )
            } else {
              if !is_absolute_http_url(value) {
                diagnostics.push(
                  make_diagnostic(
                    Warning,
                    "RBT015",
                    "sitemap is not an absolute HTTP or HTTPS URL",
                    line_no,
                    "Use a fully qualified sitemap URL.",
                  ),
                )
              }
              if !push_unique(sitemaps, value) {
                diagnostics.push(
                  make_diagnostic(
                    Info,
                    "RBT016",
                    "duplicate sitemap record",
                    line_no,
                    "Keep one copy of this sitemap URL.",
                  ),
                )
              }
            }
          CrawlDelayDirective =>
            if agents.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Warning,
                  "RBT017",
                  "crawl-delay outside a user-agent group was ignored",
                  line_no,
                  "Move it below a User-agent record.",
                ),
              )
            } else {
              let millis = parse_delay_millis(value)
              if millis < 0 {
                diagnostics.push(
                  make_diagnostic(
                    Warning,
                    "RBT018",
                    "crawl-delay is not a non-negative decimal value",
                    line_no,
                    "Use seconds with up to three fractional digits.",
                  ),
                )
              } else {
                if crawl_delay_millis >= 0 {
                  diagnostics.push(
                    make_diagnostic(
                      Warning,
                      "RBT019",
                      "later crawl-delay replaces an earlier value in this group",
                      line_no,
                      "Keep one crawl-delay per group.",
                    ),
                  )
                }
                crawl_delay_millis = millis
                group_has_records = true
                group_end_line = line_no
              }
            }
          HostDirective =>
            if value.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Warning,
                  "RBT020",
                  "empty host extension was ignored",
                  line_no,
                  "Provide a host name or remove the record.",
                ),
              )
            } else {
              ignore(push_unique(hosts, lower_ascii(value)))
            }
          CleanParamDirective =>
            if value.length() == 0 {
              diagnostics.push(
                make_diagnostic(
                  Warning,
                  "RBT021",
                  "empty clean-param extension was ignored",
                  line_no,
                  "Provide parameter names and an optional path.",
                ),
              )
            }
          UnknownDirective =>
            diagnostics.push(
              make_diagnostic(
                Info,
                "RBT012",
                "unknown directive `\{original_key}` was preserved",
                line_no,
                "Confirm that target crawlers support this extension.",
              ),
            )
        }
      }
    }
  }
  if agents.length() > 0 {
    ignore(
      finish_group(
        groups, agents, rules, crawl_delay_millis, group_start_line, group_end_line,
        options, diagnostics,
      ),
    )
  }
  {
    groups,
    sitemaps,
    hosts,
    directives,
    diagnostics,
    source_lines: source_lines.length(),
    truncated,
  }
}

///|
/// Parses robots.txt with safe defaults.
pub fn parse(input : String) -> Policy {
  parse_with_options(input, default_parse_options())
}
