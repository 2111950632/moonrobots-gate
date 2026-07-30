///|
/// Configuration for policy linting.
pub struct LintOptions {
  require_wildcard_group : Bool
  require_sitemap : Bool
  warn_unknown_directives : Bool
  max_crawl_delay_millis : Int
  max_rules_per_group : Int
} derive(Eq, Debug)

///|
pub fn default_lint_options() -> LintOptions {
  {
    require_wildcard_group: true,
    require_sitemap: false,
    warn_unknown_directives: true,
    max_crawl_delay_millis: 60000,
    max_rules_per_group: 5000,
  }
}

///|
pub fn strict_lint_options() -> LintOptions {
  {
    require_wildcard_group: true,
    require_sitemap: true,
    warn_unknown_directives: true,
    max_crawl_delay_millis: 30000,
    max_rules_per_group: 1000,
  }
}

///|
pub fn LintOptions::require_wildcard_group(self : LintOptions) -> Bool {
  self.require_wildcard_group
}

///|
pub fn LintOptions::require_sitemap(self : LintOptions) -> Bool {
  self.require_sitemap
}

///|
pub fn LintOptions::warn_unknown_directives(self : LintOptions) -> Bool {
  self.warn_unknown_directives
}

///|
pub fn LintOptions::max_crawl_delay_millis(self : LintOptions) -> Int {
  self.max_crawl_delay_millis
}

///|
pub fn LintOptions::max_rules_per_group(self : LintOptions) -> Int {
  self.max_rules_per_group
}

///|
fn lint_diag(
  severity : Severity,
  code : String,
  message : String,
  line : Int,
  hint : String,
) -> Diagnostic {
  make_diagnostic(severity, code, message, line, hint)
}

///|
fn group_contains_agent(group : Group, target : String) -> Bool {
  array_contains_string(group.agents, target)
}

///|
fn has_wildcard_group(policy : Policy) -> Bool {
  for group in policy.groups {
    if group_contains_agent(group, "*") {
      return true
    }
  }
  false
}

///|
fn group_has_block_all(group : Group) -> Bool {
  for rule in group.rules {
    if rule.kind == Disallow && rule.pattern == "/" {
      return true
    }
  }
  false
}

///|
fn group_has_allow_root(group : Group) -> Bool {
  for rule in group.rules {
    if rule.kind == Allow && rule.pattern == "/" {
      return true
    }
  }
  false
}

///|
fn rule_key(rule : Rule) -> String {
  "\{rule.kind.label()}:\{rule.normalized_pattern}"
}

///|
fn agent_occurrences(policy : Policy, agent : String) -> Int {
  let mut count = 0
  for group in policy.groups {
    if group_contains_agent(group, agent) {
      count = count + 1
    }
  }
  count
}

///|
fn invalid_percent_index(value : String) -> Int {
  let chars = value.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '%' {
      if index + 2 >= chars.length() ||
        hex_value(chars[index + 1]) < 0 ||
        hex_value(chars[index + 2]) < 0 {
        return index
      }
      index = index + 3
    } else {
      index = index + 1
    }
  }
  -1
}

///|
fn dollar_not_terminal(pattern : String) -> Bool {
  let chars = pattern.to_array()
  for index, char in chars {
    if char == '$' && index != chars.length() - 1 {
      return true
    }
  }
  false
}

///|
fn duplicate_rule_count(group : Group, rule : Rule) -> Int {
  let key = rule_key(rule)
  let mut count = 0
  for candidate in group.rules {
    if rule_key(candidate) == key {
      count = count + 1
    }
  }
  count
}

///|
fn conflicting_rule(group : Group, rule : Rule) -> Bool {
  for candidate in group.rules {
    if candidate.normalized_pattern == rule.normalized_pattern &&
      candidate.kind != rule.kind {
      return true
    }
  }
  false
}

///|
fn shadowed_by_identical_prefix(group : Group, index : Int) -> Bool {
  let rule = group.rules[index]
  for previous = 0; previous < index; previous = previous + 1 {
    let candidate = group.rules[previous]
    if candidate.kind == rule.kind &&
      candidate.normalized_pattern == rule.normalized_pattern {
      return true
    }
  }
  false
}

///|
fn lint_group(
  policy : Policy,
  group : Group,
  options : LintOptions,
  output : Array[Diagnostic],
) -> Unit {
  if group.rules.length() == 0 && group.crawl_delay_millis < 0 {
    output.push(
      lint_diag(
        Info,
        "LNT004",
        "user-agent group has no effective records",
        group.start_line,
        "Add rules or remove the empty group.",
      ),
    )
  }
  if group.rules.length() > options.max_rules_per_group {
    output.push(
      lint_diag(
        Warning,
        "LNT005",
        "group has more rules than the configured maintainability threshold",
        group.start_line,
        "Split agents or simplify overlapping rules.",
      ),
    )
  }
  if group.crawl_delay_millis > options.max_crawl_delay_millis {
    output.push(
      lint_diag(
        Warning,
        "LNT006",
        "crawl-delay exceeds the configured operational threshold",
        group.start_line,
        "Confirm that such a slow crawl cadence is intentional.",
      ),
    )
  }
  if group_contains_agent(group, "*") && group.agents.length() > 1 {
    output.push(
      lint_diag(
        Warning,
        "LNT007",
        "wildcard and named agents share one group",
        group.start_line,
        "Separate wildcard and named agents to avoid crawler differences.",
      ),
    )
  }
  if group_contains_agent(group, "*") && group_has_block_all(group) {
    output.push(
      lint_diag(
        Warning,
        "LNT008",
        "wildcard group blocks the entire site",
        group.start_line,
        "Confirm that all unspecified crawlers should be denied.",
      ),
    )
  }
  if group_has_block_all(group) && group_has_allow_root(group) {
    output.push(
      lint_diag(
        Warning,
        "LNT009",
        "group contains equivalent root allow and disallow rules",
        group.start_line,
        "Allow wins the tie; remove the misleading rule.",
      ),
    )
  }
  for agent in group.agents {
    if agent != "*" && agent_occurrences(policy, agent) > 1 {
      let first = first_group_line_for_agent(policy, agent)
      if group.start_line != first {
        output.push(
          lint_diag(
            Info,
            "LNT010",
            "agent appears in multiple groups; their rules are merged",
            group.start_line,
            "Keep related rules together when practical.",
          ),
        )
      }
    }
  }
  for index, rule in group.rules {
    if rule.pattern.length() > 0 && !rule.pattern.has_prefix("/") {
      output.push(
        lint_diag(
          Warning,
          "LNT011",
          "path rule does not begin with `/`",
          rule.line,
          "Use an origin-relative path.",
        ),
      )
    }
    if invalid_percent_index(rule.pattern) >= 0 {
      output.push(
        lint_diag(
          Warning,
          "LNT012",
          "path rule contains malformed percent encoding",
          rule.line,
          "Write percent escapes as `%` followed by two hexadecimal digits.",
        ),
      )
    }
    if dollar_not_terminal(rule.pattern) {
      output.push(
        lint_diag(
          Warning,
          "LNT013",
          "`$` only acts as an end anchor at the end of a rule",
          rule.line,
          "Move `$` to the end or percent-encode a literal dollar sign.",
        ),
      )
    }
    if rule.pattern.has_suffix("*") {
      output.push(
        lint_diag(
          Info,
          "LNT014",
          "trailing wildcard is redundant",
          rule.line,
          "Remove the final `*` without changing prefix-match behavior.",
        ),
      )
    }
    if count_char(rule.pattern, '*') > 8 {
      output.push(
        lint_diag(
          Warning,
          "LNT015",
          "rule contains many wildcards and may be expensive to evaluate",
          rule.line,
          "Prefer a smaller number of targeted rules.",
        ),
      )
    }
    if duplicate_rule_count(group, rule) > 1 &&
      shadowed_by_identical_prefix(group, index) {
      output.push(
        lint_diag(
          Info,
          "LNT016",
          "duplicate rule has no additional effect",
          rule.line,
          "Remove the duplicate rule.",
        ),
      )
    }
    if conflicting_rule(group, rule) && rule.kind == Disallow {
      output.push(
        lint_diag(
          Info,
          "LNT017",
          "equivalent Allow rule wins over this Disallow rule",
          rule.line,
          "Remove one side or make one path more specific.",
        ),
      )
    }
    if rule.pattern.contains("?") {
      output.push(
        lint_diag(
          Info,
          "LNT018",
          "rule matches a query component as well as a path",
          rule.line,
          "Confirm that query-sensitive crawling behavior is intended.",
        ),
      )
    }
  }
}

///|
fn first_group_line_for_agent(policy : Policy, agent : String) -> Int {
  for group in policy.groups {
    if group_contains_agent(group, agent) {
      return group.start_line
    }
  }
  0
}

///|
/// Performs semantic and maintainability checks beyond parsing.
pub fn lint_with_options(
  policy : Policy,
  options : LintOptions,
) -> Array[Diagnostic] {
  let output : Array[Diagnostic] = []
  if policy.groups.length() == 0 {
    output.push(
      lint_diag(
        Warning,
        "LNT001",
        "policy defines no user-agent groups",
        1,
        "Add a User-agent group or intentionally serve an empty file.",
      ),
    )
  }
  if options.require_wildcard_group && !has_wildcard_group(policy) {
    output.push(
      lint_diag(
        Info,
        "LNT002",
        "policy has no wildcard fallback group",
        1,
        "Add `User-agent: *` when unspecified crawlers need explicit rules.",
      ),
    )
  }
  if options.require_sitemap && policy.sitemaps.length() == 0 {
    output.push(
      lint_diag(
        Info,
        "LNT003",
        "policy does not advertise a sitemap",
        1,
        "Add an absolute Sitemap URL when the site publishes one.",
      ),
    )
  }
  for group in policy.groups {
    lint_group(policy, group, options, output)
  }
  if options.warn_unknown_directives {
    for directive in policy.directives {
      if directive.kind == UnknownDirective {
        output.push(
          lint_diag(
            Info,
            "LNT019",
            "non-standard directive may be ignored by crawlers",
            directive.line(),
            "Document the target crawler or remove the extension.",
          ),
        )
      }
    }
  }
  for sitemap in policy.sitemaps {
    let parsed = parse_url(sitemap)
    if !parsed.valid() {
      output.push(
        lint_diag(
          Warning,
          "LNT021",
          "sitemap directive is not a valid absolute HTTP or HTTPS URL",
          sitemap_directive_line(policy, sitemap),
          "Use an absolute URL such as https://example.com/sitemap.xml.",
        ),
      )
    } else if parsed.fragment().length() > 0 {
      output.push(
        lint_diag(
          Warning,
          "LNT020",
          "sitemap URL contains a fragment",
          sitemap_directive_line(policy, sitemap),
          "Remove the fragment from the sitemap location.",
        ),
      )
    }
  }
  output
}

///|
fn sitemap_directive_line(policy : Policy, sitemap : String) -> Int {
  for directive in policy.directives {
    if directive.kind == SitemapDirective && directive.value == sitemap {
      return directive.line()
    }
  }
  1
}

///|
pub fn lint(policy : Policy) -> Array[Diagnostic] {
  lint_with_options(policy, default_lint_options())
}

///|
pub fn all_diagnostics_with_options(
  policy : Policy,
  options : LintOptions,
) -> Array[Diagnostic] {
  let output : Array[Diagnostic] = []
  for diagnostic in policy.diagnostics {
    output.push(diagnostic)
  }
  for diagnostic in lint_with_options(policy, options) {
    output.push(diagnostic)
  }
  output
}

///|
pub fn all_diagnostics(policy : Policy) -> Array[Diagnostic] {
  all_diagnostics_with_options(policy, default_lint_options())
}

///|
pub fn diagnostics_at_least(
  diagnostics : Array[Diagnostic],
  severity : Severity,
) -> Array[Diagnostic] {
  let output : Array[Diagnostic] = []
  for diagnostic in diagnostics {
    if diagnostic.severity.rank() >= severity.rank() {
      output.push(diagnostic)
    }
  }
  output
}

///|
pub fn has_diagnostic_code(
  diagnostics : Array[Diagnostic],
  code : String,
) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      return true
    }
  }
  false
}
