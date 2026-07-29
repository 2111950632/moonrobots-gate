///|
/// Whether a matching path is allowed or disallowed.
pub(all) enum RuleKind {
  Allow
  Disallow
} derive(Eq, Debug)

///|
pub fn RuleKind::label(self : RuleKind) -> String {
  match self {
    Allow => "allow"
    Disallow => "disallow"
  }
}

///|
pub fn RuleKind::directive_name(self : RuleKind) -> String {
  match self {
    Allow => "Allow"
    Disallow => "Disallow"
  }
}

///|
pub fn RuleKind::tie_priority(self : RuleKind) -> Int {
  match self {
    Allow => 1
    Disallow => 0
  }
}

///|
/// Classification of a parsed robots.txt record.
pub(all) enum DirectiveKind {
  UserAgentDirective
  AllowDirective
  DisallowDirective
  SitemapDirective
  CrawlDelayDirective
  HostDirective
  CleanParamDirective
  UnknownDirective
} derive(Eq, Debug)

///|
pub fn DirectiveKind::label(self : DirectiveKind) -> String {
  match self {
    UserAgentDirective => "user-agent"
    AllowDirective => "allow"
    DisallowDirective => "disallow"
    SitemapDirective => "sitemap"
    CrawlDelayDirective => "crawl-delay"
    HostDirective => "host"
    CleanParamDirective => "clean-param"
    UnknownDirective => "unknown"
  }
}

///|
/// Severity of a parser or policy diagnostic.
pub(all) enum Severity {
  Info
  Warning
  Error
} derive(Eq, Debug)

///|
pub fn Severity::label(self : Severity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn Severity::rank(self : Severity) -> Int {
  match self {
    Info => 0
    Warning => 1
    Error => 2
  }
}

///|
/// Source location for a line-oriented robots.txt record.
pub struct SourceSpan {
  line : Int
  column : Int
  length : Int
} derive(Eq, Debug)

///|
pub fn SourceSpan::line(self : SourceSpan) -> Int {
  self.line
}

///|
pub fn SourceSpan::column(self : SourceSpan) -> Int {
  self.column
}

///|
pub fn SourceSpan::length(self : SourceSpan) -> Int {
  self.length
}

///|
pub fn SourceSpan::summary(self : SourceSpan) -> String {
  "line \{self.line}, column \{self.column}"
}

///|
/// A preserved source directive, including extensions and unknown fields.
pub struct Directive {
  kind : DirectiveKind
  key : String
  value : String
  raw : String
  span : SourceSpan
} derive(Eq, Debug)

///|
pub fn Directive::kind(self : Directive) -> DirectiveKind {
  self.kind
}

///|
pub fn Directive::key(self : Directive) -> String {
  self.key
}

///|
pub fn Directive::value(self : Directive) -> String {
  self.value
}

///|
pub fn Directive::raw(self : Directive) -> String {
  self.raw
}

///|
pub fn Directive::span(self : Directive) -> SourceSpan {
  self.span
}

///|
pub fn Directive::line(self : Directive) -> Int {
  self.span.line
}

///|
pub fn Directive::is_standard(self : Directive) -> Bool {
  match self.kind {
    UserAgentDirective | AllowDirective | DisallowDirective => true
    _ => false
  }
}

///|
/// A source-aware parser or policy diagnostic.
pub struct Diagnostic {
  severity : Severity
  code : String
  message : String
  span : SourceSpan
  hint : String
} derive(Eq, Debug)

///|
pub fn Diagnostic::severity(self : Diagnostic) -> Severity {
  self.severity
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> String {
  self.code
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::span(self : Diagnostic) -> SourceSpan {
  self.span
}

///|
pub fn Diagnostic::line(self : Diagnostic) -> Int {
  self.span.line
}

///|
pub fn Diagnostic::hint(self : Diagnostic) -> String {
  self.hint
}

///|
pub fn Diagnostic::summary(self : Diagnostic) -> String {
  "\{self.severity.label()}[\{self.code}] line \{self.span.line}: \{self.message}"
}

///|
/// Limits used by the defensive parser.
pub struct ParseOptions {
  max_input_chars : Int
  max_lines : Int
  max_line_chars : Int
  max_groups : Int
  max_rules : Int
  preserve_unknown : Bool
} derive(Eq, Debug)

///|
pub fn default_parse_options() -> ParseOptions {
  {
    max_input_chars: 512000,
    max_lines: 10000,
    max_line_chars: 8192,
    max_groups: 1000,
    max_rules: 100000,
    preserve_unknown: true,
  }
}

///|
pub fn strict_parse_options() -> ParseOptions {
  {
    max_input_chars: 512000,
    max_lines: 10000,
    max_line_chars: 2048,
    max_groups: 500,
    max_rules: 50000,
    preserve_unknown: true,
  }
}

///|
pub fn parse_options(
  max_input_chars : Int,
  max_lines : Int,
  max_line_chars : Int,
  max_groups : Int,
  max_rules : Int,
  preserve_unknown : Bool,
) -> ParseOptions {
  {
    max_input_chars,
    max_lines,
    max_line_chars,
    max_groups,
    max_rules,
    preserve_unknown,
  }
}

///|
pub fn ParseOptions::max_input_chars(self : ParseOptions) -> Int {
  self.max_input_chars
}

///|
pub fn ParseOptions::max_lines(self : ParseOptions) -> Int {
  self.max_lines
}

///|
pub fn ParseOptions::max_line_chars(self : ParseOptions) -> Int {
  self.max_line_chars
}

///|
pub fn ParseOptions::max_groups(self : ParseOptions) -> Int {
  self.max_groups
}

///|
pub fn ParseOptions::max_rules(self : ParseOptions) -> Int {
  self.max_rules
}

///|
pub fn ParseOptions::preserve_unknown(self : ParseOptions) -> Bool {
  self.preserve_unknown
}

///|
/// One parsed Allow or Disallow rule.
pub struct Rule {
  kind : RuleKind
  pattern : String
  normalized_pattern : String
  line : Int
} derive(Eq, Debug)

///|
pub fn Rule::kind(self : Rule) -> RuleKind {
  self.kind
}

///|
pub fn Rule::pattern(self : Rule) -> String {
  self.pattern
}

///|
pub fn Rule::normalized_pattern(self : Rule) -> String {
  self.normalized_pattern
}

///|
pub fn Rule::line(self : Rule) -> Int {
  self.line
}

///|
pub fn Rule::is_empty(self : Rule) -> Bool {
  self.pattern.length() == 0
}

///|
pub fn Rule::specificity(self : Rule) -> Int {
  rule_specificity(self.normalized_pattern)
}

///|
/// A user-agent group in robots.txt.
pub struct Group {
  agents : Array[String]
  rules : Array[Rule]
  crawl_delay_millis : Int
  start_line : Int
  end_line : Int
} derive(Eq, Debug)

///|
pub fn Group::agents(self : Group) -> Array[String] {
  self.agents
}

///|
pub fn Group::rules(self : Group) -> Array[Rule] {
  self.rules
}

///|
pub fn Group::crawl_delay_millis(self : Group) -> Int {
  self.crawl_delay_millis
}

///|
pub fn Group::has_crawl_delay(self : Group) -> Bool {
  self.crawl_delay_millis >= 0
}

///|
pub fn Group::start_line(self : Group) -> Int {
  self.start_line
}

///|
pub fn Group::end_line(self : Group) -> Int {
  self.end_line
}

///|
pub fn Group::agent_count(self : Group) -> Int {
  self.agents.length()
}

///|
pub fn Group::rule_count(self : Group) -> Int {
  self.rules.length()
}

///|
/// Parsed robots.txt policy with source metadata and diagnostics.
pub struct Policy {
  groups : Array[Group]
  sitemaps : Array[String]
  hosts : Array[String]
  directives : Array[Directive]
  diagnostics : Array[Diagnostic]
  source_lines : Int
  truncated : Bool
} derive(Eq, Debug)

///|
pub fn Policy::groups(self : Policy) -> Array[Group] {
  self.groups
}

///|
pub fn Policy::sitemaps(self : Policy) -> Array[String] {
  self.sitemaps
}

///|
pub fn Policy::hosts(self : Policy) -> Array[String] {
  self.hosts
}

///|
pub fn Policy::directives(self : Policy) -> Array[Directive] {
  self.directives
}

///|
pub fn Policy::diagnostics(self : Policy) -> Array[Diagnostic] {
  self.diagnostics
}

///|
pub fn Policy::source_lines(self : Policy) -> Int {
  self.source_lines
}

///|
pub fn Policy::truncated(self : Policy) -> Bool {
  self.truncated
}

///|
pub fn Policy::group_count(self : Policy) -> Int {
  self.groups.length()
}

///|
pub fn Policy::rule_count(self : Policy) -> Int {
  let mut count = 0
  for group in self.groups {
    count = count + group.rules.length()
  }
  count
}

///|
pub fn Policy::diagnostic_count(self : Policy) -> Int {
  self.diagnostics.length()
}

///|
pub fn Policy::error_count(self : Policy) -> Int {
  let mut count = 0
  for diagnostic in self.diagnostics {
    if diagnostic.severity == Error {
      count = count + 1
    }
  }
  count
}

///|
pub fn Policy::warning_count(self : Policy) -> Int {
  let mut count = 0
  for diagnostic in self.diagnostics {
    if diagnostic.severity == Warning {
      count = count + 1
    }
  }
  count
}

///|
pub fn Policy::is_valid(self : Policy) -> Bool {
  self.error_count() == 0
}

///|
/// One step in an explainable access decision.
pub struct DecisionStep {
  stage : String
  detail : String
} derive(Eq, Debug)

///|
pub fn DecisionStep::stage(self : DecisionStep) -> String {
  self.stage
}

///|
pub fn DecisionStep::detail(self : DecisionStep) -> String {
  self.detail
}

///|
pub fn DecisionStep::summary(self : DecisionStep) -> String {
  "\{self.stage}: \{self.detail}"
}

///|
/// Decision returned for a user-agent and path.
pub struct Decision {
  allowed : Bool
  agent : String
  path : String
  normalized_path : String
  rule_kind : RuleKind
  rule_pattern : String
  line : Int
  reason : String
  agent_specificity : Int
  rule_specificity : Int
  matched_groups : Int
  trace : Array[DecisionStep]
} derive(Eq, Debug)

///|
pub fn Decision::allowed(self : Decision) -> Bool {
  self.allowed
}

///|
pub fn Decision::agent(self : Decision) -> String {
  self.agent
}

///|
pub fn Decision::path(self : Decision) -> String {
  self.path
}

///|
pub fn Decision::normalized_path(self : Decision) -> String {
  self.normalized_path
}

///|
pub fn Decision::rule_kind(self : Decision) -> RuleKind {
  self.rule_kind
}

///|
pub fn Decision::rule_pattern(self : Decision) -> String {
  self.rule_pattern
}

///|
pub fn Decision::line(self : Decision) -> Int {
  self.line
}

///|
pub fn Decision::reason(self : Decision) -> String {
  self.reason
}

///|
pub fn Decision::agent_specificity(self : Decision) -> Int {
  self.agent_specificity
}

///|
pub fn Decision::rule_specificity(self : Decision) -> Int {
  self.rule_specificity
}

///|
pub fn Decision::matched_groups(self : Decision) -> Int {
  self.matched_groups
}

///|
pub fn Decision::trace(self : Decision) -> Array[DecisionStep] {
  self.trace
}

///|
pub fn Decision::verdict(self : Decision) -> String {
  if self.allowed {
    "ALLOW"
  } else {
    "DENY"
  }
}

///|
pub fn Decision::summary(self : Decision) -> String {
  if self.line == 0 {
    "\{self.verdict()} \{self.agent} \{self.path} by default: \{self.reason}"
  } else {
    "\{self.verdict()} \{self.agent} \{self.path} via \{self.rule_kind.label()} `\{self.rule_pattern}` at line \{self.line}"
  }
}

///|
/// Compact aggregate statistics for a policy.
pub struct PolicyStats {
  groups : Int
  agents : Int
  rules : Int
  allows : Int
  disallows : Int
  sitemaps : Int
  diagnostics : Int
} derive(Eq, Debug)

///|
pub fn PolicyStats::groups(self : PolicyStats) -> Int {
  self.groups
}

///|
pub fn PolicyStats::agents(self : PolicyStats) -> Int {
  self.agents
}

///|
pub fn PolicyStats::rules(self : PolicyStats) -> Int {
  self.rules
}

///|
pub fn PolicyStats::allows(self : PolicyStats) -> Int {
  self.allows
}

///|
pub fn PolicyStats::disallows(self : PolicyStats) -> Int {
  self.disallows
}

///|
pub fn PolicyStats::sitemaps(self : PolicyStats) -> Int {
  self.sitemaps
}

///|
pub fn PolicyStats::diagnostics(self : PolicyStats) -> Int {
  self.diagnostics
}

///|
pub fn Policy::stats(self : Policy) -> PolicyStats {
  let mut agent_count = 0
  let mut rule_count = 0
  let mut allow_count = 0
  let mut disallow_count = 0
  for group in self.groups {
    agent_count = agent_count + group.agents.length()
    for rule in group.rules {
      rule_count = rule_count + 1
      if rule.kind == Allow {
        allow_count = allow_count + 1
      } else {
        disallow_count = disallow_count + 1
      }
    }
  }
  {
    groups: self.groups.length(),
    agents: agent_count,
    rules: rule_count,
    allows: allow_count,
    disallows: disallow_count,
    sitemaps: self.sitemaps.length(),
    diagnostics: self.diagnostics.length(),
  }
}
