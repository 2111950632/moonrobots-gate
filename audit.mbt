///|
/// Aggregated, deterministic policy audit suitable for CI output.
pub struct PolicyAudit {
  policy : Policy
  diagnostics : Array[Diagnostic]
  matrix : DecisionMatrix
  risk_score : Int
  grade : String
  explicit_decisions : Int
  default_decisions : Int
} derive(Eq, Debug)

///|
pub fn PolicyAudit::policy(self : PolicyAudit) -> Policy {
  self.policy
}

///|
pub fn PolicyAudit::diagnostics(self : PolicyAudit) -> Array[Diagnostic] {
  self.diagnostics
}

///|
pub fn PolicyAudit::matrix(self : PolicyAudit) -> DecisionMatrix {
  self.matrix
}

///|
pub fn PolicyAudit::risk_score(self : PolicyAudit) -> Int {
  self.risk_score
}

///|
pub fn PolicyAudit::grade(self : PolicyAudit) -> String {
  self.grade
}

///|
pub fn PolicyAudit::explicit_decisions(self : PolicyAudit) -> Int {
  self.explicit_decisions
}

///|
pub fn PolicyAudit::default_decisions(self : PolicyAudit) -> Int {
  self.default_decisions
}

///|
pub fn PolicyAudit::passed(self : PolicyAudit) -> Bool {
  self.policy.error_count() == 0 && self.risk_score < 60
}

///|
fn risk_for_diagnostic(diagnostic : Diagnostic) -> Int {
  match diagnostic.severity {
    Error => 20
    Warning => 7
    Info => 1
  }
}

///|
fn clamp_score(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 100 {
    100
  } else {
    value
  }
}

///|
fn grade_for_score(score : Int) -> String {
  if score < 10 {
    "A"
  } else if score < 25 {
    "B"
  } else if score < 45 {
    "C"
  } else if score < 70 {
    "D"
  } else {
    "F"
  }
}

///|
fn calculate_risk(
  policy : Policy,
  diagnostics : Array[Diagnostic],
  matrix : DecisionMatrix,
) -> Int {
  let mut score = 0
  for diagnostic in diagnostics {
    score = score + risk_for_diagnostic(diagnostic)
  }
  if policy.truncated {
    score = score + 30
  }
  if policy.groups.length() == 0 {
    score = score + 10
  }
  if matrix.total() > 0 && matrix.default_count == matrix.total() {
    score = score + 8
  }
  if matrix.denied_count == matrix.total() && matrix.total() > 0 {
    score = score + 12
  }
  clamp_score(score)
}

///|
/// Parses, lints, and probes a policy in one deterministic operation.
pub fn audit(
  input : String,
  agents : Array[String],
  paths : Array[String],
) -> PolicyAudit {
  let policy = parse(input)
  let diagnostics = all_diagnostics(policy)
  let matrix = run_matrix(policy, build_probe_grid(agents, paths))
  let risk_score = calculate_risk(policy, diagnostics, matrix)
  {
    policy,
    diagnostics,
    matrix,
    risk_score,
    grade: grade_for_score(risk_score),
    explicit_decisions: matrix.total() - matrix.default_count,
    default_decisions: matrix.default_count,
  }
}

///|
pub fn audit_default(input : String) -> PolicyAudit {
  audit(input, ["*", "Googlebot", "Bingbot", "GPTBot"], [
    "/", "/robots.txt", "/admin/", "/api/", "/private/", "/public/",
  ])
}

///|
fn count_severity(diagnostics : Array[Diagnostic], severity : Severity) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.severity == severity {
      count = count + 1
    }
  }
  count
}

///|
pub fn render_audit_markdown(audit : PolicyAudit) -> String {
  let stats = audit.policy.stats()
  let output = StringBuilder::new()
  output.write_string("# MoonRobots Gate audit\n\n")
  output.write_string("Grade: **\{audit.grade}**\n\n")
  output.write_string("Risk score: **\{audit.risk_score}/100**\n\n")
  output.write_string("## Policy\n\n")
  output.write_string("- Groups: \{stats.groups}\n")
  output.write_string("- Agents: \{stats.agents}\n")
  output.write_string("- Rules: \{stats.rules}\n")
  output.write_string("- Sitemaps: \{stats.sitemaps}\n")
  output.write_string("- Truncated: \{audit.policy.truncated}\n\n")
  output.write_string("## Diagnostics\n\n")
  output.write_string("- Errors: \{count_severity(audit.diagnostics, Error)}\n")
  output.write_string(
    "- Warnings: \{count_severity(audit.diagnostics, Warning)}\n",
  )
  output.write_string(
    "- Information: \{count_severity(audit.diagnostics, Info)}\n\n",
  )
  for diagnostic in audit.diagnostics {
    output.write_string("- ")
    output.write_string(diagnostic.summary())
    output.write_char('\n')
  }
  output.write_string("\n## Access matrix\n\n")
  output.write_string(render_matrix_markdown(audit.matrix))
  output.to_string()
}

///|
fn json_escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t")
}

///|
pub fn render_audit_json(audit : PolicyAudit) -> String {
  let stats = audit.policy.stats()
  let output = StringBuilder::new()
  output.write_string("{\n")
  output.write_string("  \"grade\": \"\{json_escape(audit.grade)}\",\n")
  output.write_string("  \"risk_score\": \{audit.risk_score},\n")
  output.write_string("  \"passed\": \{audit.passed()},\n")
  output.write_string("  \"groups\": \{stats.groups},\n")
  output.write_string("  \"rules\": \{stats.rules},\n")
  output.write_string("  \"diagnostics\": [\n")
  for index, diagnostic in audit.diagnostics {
    output.write_string("    {")
    output.write_string("\"severity\":\"\{diagnostic.severity.label()}\",")
    output.write_string("\"code\":\"\{json_escape(diagnostic.code)}\",")
    output.write_string("\"line\":\{diagnostic.line()},")
    output.write_string("\"message\":\"\{json_escape(diagnostic.message)}\"}")
    if index + 1 < audit.diagnostics.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  output.write_string("  ],\n")
  output.write_string("  \"probes\": [\n")
  for index, outcome in audit.matrix.outcomes {
    output.write_string("    {")
    output.write_string("\"name\":\"\{json_escape(outcome.probe.name)}\",")
    output.write_string("\"agent\":\"\{json_escape(outcome.probe.agent)}\",")
    output.write_string("\"path\":\"\{json_escape(outcome.probe.path)}\",")
    output.write_string("\"allowed\":\{outcome.decision.allowed},")
    output.write_string("\"line\":\{outcome.decision.line}}")
    if index + 1 < audit.matrix.outcomes.length() {
      output.write_char(',')
    }
    output.write_char('\n')
  }
  output.write_string("  ]\n")
  output.write_string("}\n")
  output.to_string()
}

///|
pub fn audit_exit_code(audit : PolicyAudit) -> Int {
  if audit.policy.error_count() > 0 {
    2
  } else if audit.risk_score >= 60 {
    1
  } else {
    0
  }
}
