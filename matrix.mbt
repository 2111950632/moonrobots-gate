///|
/// A named user-agent and path probe.
pub struct AccessProbe {
  name : String
  agent : String
  path : String
} derive(Eq, Debug)

///|
pub fn access_probe(
  name : String,
  agent : String,
  path : String,
) -> AccessProbe {
  { name, agent, path }
}

///|
pub fn AccessProbe::name(self : AccessProbe) -> String {
  self.name
}

///|
pub fn AccessProbe::agent(self : AccessProbe) -> String {
  self.agent
}

///|
pub fn AccessProbe::path(self : AccessProbe) -> String {
  self.path
}

///|
/// Result of running one access probe.
pub struct ProbeOutcome {
  probe : AccessProbe
  decision : Decision
} derive(Eq, Debug)

///|
pub fn ProbeOutcome::probe(self : ProbeOutcome) -> AccessProbe {
  self.probe
}

///|
pub fn ProbeOutcome::decision(self : ProbeOutcome) -> Decision {
  self.decision
}

///|
pub fn ProbeOutcome::allowed(self : ProbeOutcome) -> Bool {
  self.decision.allowed
}

///|
pub fn ProbeOutcome::summary(self : ProbeOutcome) -> String {
  "\{self.probe.name}: \{self.decision.summary()}"
}

///|
/// Deterministic batch of access decisions.
pub struct DecisionMatrix {
  outcomes : Array[ProbeOutcome]
  allowed_count : Int
  denied_count : Int
  default_count : Int
} derive(Eq, Debug)

///|
pub fn DecisionMatrix::outcomes(self : DecisionMatrix) -> Array[ProbeOutcome] {
  self.outcomes
}

///|
pub fn DecisionMatrix::allowed_count(self : DecisionMatrix) -> Int {
  self.allowed_count
}

///|
pub fn DecisionMatrix::denied_count(self : DecisionMatrix) -> Int {
  self.denied_count
}

///|
pub fn DecisionMatrix::default_count(self : DecisionMatrix) -> Int {
  self.default_count
}

///|
pub fn DecisionMatrix::total(self : DecisionMatrix) -> Int {
  self.outcomes.length()
}

///|
pub fn DecisionMatrix::all_allowed(self : DecisionMatrix) -> Bool {
  self.denied_count == 0
}

///|
/// Evaluates a list of named probes against one policy.
pub fn run_matrix(
  policy : Policy,
  probes : Array[AccessProbe],
) -> DecisionMatrix {
  let outcomes : Array[ProbeOutcome] = []
  let mut allowed_count = 0
  let mut denied_count = 0
  let mut default_count = 0
  for probe in probes {
    let decision = decide(policy, probe.agent, probe.path)
    outcomes.push({ probe, decision })
    if decision.allowed {
      allowed_count = allowed_count + 1
    } else {
      denied_count = denied_count + 1
    }
    if decision.line == 0 {
      default_count = default_count + 1
    }
  }
  { outcomes, allowed_count, denied_count, default_count }
}

///|
pub fn build_probe_grid(
  agents : Array[String],
  paths : Array[String],
) -> Array[AccessProbe] {
  let probes : Array[AccessProbe] = []
  for agent in agents {
    for path in paths {
      probes.push({ name: "\{agent} \{path}", agent, path })
    }
  }
  probes
}

///|
pub fn find_outcome(matrix : DecisionMatrix, name : String) -> ProbeOutcome? {
  for outcome in matrix.outcomes {
    if outcome.probe.name == name {
      return Some(outcome)
    }
  }
  None
}

///|
pub fn denied_outcomes(matrix : DecisionMatrix) -> Array[ProbeOutcome] {
  let output : Array[ProbeOutcome] = []
  for outcome in matrix.outcomes {
    if !outcome.decision.allowed {
      output.push(outcome)
    }
  }
  output
}

///|
pub fn default_outcomes(matrix : DecisionMatrix) -> Array[ProbeOutcome] {
  let output : Array[ProbeOutcome] = []
  for outcome in matrix.outcomes {
    if outcome.decision.line == 0 {
      output.push(outcome)
    }
  }
  output
}

///|
fn escape_markdown_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new=" ")
}

///|
fn escape_csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"\{value.replace_all(old="\"", new="\"\"")}\""
  } else {
    value
  }
}

///|
pub fn render_matrix_markdown(matrix : DecisionMatrix) -> String {
  let output = StringBuilder::new()
  output.write_string("| Probe | Agent | Path | Verdict | Rule | Line |\n")
  output.write_string("|---|---|---|---|---|---:|\n")
  for outcome in matrix.outcomes {
    let decision = outcome.decision
    let rule = if decision.line == 0 {
      "default"
    } else {
      "\{decision.rule_kind.label()} \{decision.rule_pattern}"
    }
    output.write_string("| ")
    output.write_string(escape_markdown_cell(outcome.probe.name))
    output.write_string(" | ")
    output.write_string(escape_markdown_cell(outcome.probe.agent))
    output.write_string(" | ")
    output.write_string(escape_markdown_cell(outcome.probe.path))
    output.write_string(" | ")
    output.write_string(decision.verdict())
    output.write_string(" | ")
    output.write_string(escape_markdown_cell(rule))
    output.write_string(" | ")
    output.write_string("\{decision.line}")
    output.write_string(" |\n")
  }
  output.to_string()
}

///|
pub fn render_matrix_csv(matrix : DecisionMatrix) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "probe,agent,path,allowed,rule_kind,rule_pattern,line,reason\n",
  )
  for outcome in matrix.outcomes {
    let decision = outcome.decision
    let row = [
      escape_csv_cell(outcome.probe.name),
      escape_csv_cell(outcome.probe.agent),
      escape_csv_cell(outcome.probe.path),
      if decision.allowed {
        "true"
      } else {
        "false"
      },
      decision.rule_kind.label(),
      escape_csv_cell(decision.rule_pattern),
      "\{decision.line}",
      escape_csv_cell(decision.reason),
    ]
    output.write_string(join_strings(row, ","))
    output.write_char('\n')
  }
  output.to_string()
}

///|
/// Behavior classification used when comparing two matrices.
pub(all) enum BehaviorChange {
  UnchangedAllow
  UnchangedDeny
  BecameAllowed
  BecameDenied
  MissingBaseline
} derive(Eq, Debug)

///|
pub fn BehaviorChange::label(self : BehaviorChange) -> String {
  match self {
    UnchangedAllow => "unchanged-allow"
    UnchangedDeny => "unchanged-deny"
    BecameAllowed => "became-allowed"
    BecameDenied => "became-denied"
    MissingBaseline => "missing-baseline"
  }
}

///|
pub struct MatrixComparison {
  name : String
  before : ProbeOutcome?
  after : ProbeOutcome
  change : BehaviorChange
} derive(Eq, Debug)

///|
pub fn MatrixComparison::name(self : MatrixComparison) -> String {
  self.name
}

///|
pub fn MatrixComparison::before(self : MatrixComparison) -> ProbeOutcome? {
  self.before
}

///|
pub fn MatrixComparison::after(self : MatrixComparison) -> ProbeOutcome {
  self.after
}

///|
pub fn MatrixComparison::change(self : MatrixComparison) -> BehaviorChange {
  self.change
}

///|
pub fn compare_matrices(
  before : DecisionMatrix,
  after : DecisionMatrix,
) -> Array[MatrixComparison] {
  let output : Array[MatrixComparison] = []
  for after_outcome in after.outcomes {
    let before_outcome = find_outcome(before, after_outcome.probe.name)
    let change = match before_outcome {
      None => MissingBaseline
      Some(previous) =>
        if previous.allowed() && after_outcome.allowed() {
          UnchangedAllow
        } else if !previous.allowed() && !after_outcome.allowed() {
          UnchangedDeny
        } else if after_outcome.allowed() {
          BecameAllowed
        } else {
          BecameDenied
        }
    }
    output.push({
      name: after_outcome.probe.name,
      before: before_outcome,
      after: after_outcome,
      change,
    })
  }
  output
}

///|
pub fn behavior_flip_count(comparisons : Array[MatrixComparison]) -> Int {
  let mut count = 0
  for comparison in comparisons {
    if comparison.change == BecameAllowed || comparison.change == BecameDenied {
      count = count + 1
    }
  }
  count
}

///|
pub fn render_matrix_comparison(
  comparisons : Array[MatrixComparison],
) -> String {
  let output = StringBuilder::new()
  for comparison in comparisons {
    output.write_string(comparison.change.label())
    output.write_string(": ")
    output.write_string(comparison.name)
    output.write_char('\n')
  }
  output.to_string()
}
