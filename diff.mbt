///|
/// Structural or behavioral policy change.
pub(all) enum ChangeKind {
  GroupAdded
  GroupRemoved
  RuleAdded
  RuleRemoved
  SitemapAdded
  SitemapRemoved
  HostAdded
  HostRemoved
  DelayChanged
  AccessBecameAllowed
  AccessBecameDenied
} derive(Eq, Debug)

///|
pub fn ChangeKind::label(self : ChangeKind) -> String {
  match self {
    GroupAdded => "group-added"
    GroupRemoved => "group-removed"
    RuleAdded => "rule-added"
    RuleRemoved => "rule-removed"
    SitemapAdded => "sitemap-added"
    SitemapRemoved => "sitemap-removed"
    HostAdded => "host-added"
    HostRemoved => "host-removed"
    DelayChanged => "delay-changed"
    AccessBecameAllowed => "access-became-allowed"
    AccessBecameDenied => "access-became-denied"
  }
}

///|
pub fn ChangeKind::is_behavioral(self : ChangeKind) -> Bool {
  self == AccessBecameAllowed || self == AccessBecameDenied
}

///|
/// One source-aware difference between two policies.
pub struct PolicyChange {
  kind : ChangeKind
  subject : String
  before : String
  after : String
  line_before : Int
  line_after : Int
} derive(Eq, Debug)

///|
pub fn PolicyChange::kind(self : PolicyChange) -> ChangeKind {
  self.kind
}

///|
pub fn PolicyChange::subject(self : PolicyChange) -> String {
  self.subject
}

///|
pub fn PolicyChange::before(self : PolicyChange) -> String {
  self.before
}

///|
pub fn PolicyChange::after(self : PolicyChange) -> String {
  self.after
}

///|
pub fn PolicyChange::line_before(self : PolicyChange) -> Int {
  self.line_before
}

///|
pub fn PolicyChange::line_after(self : PolicyChange) -> Int {
  self.line_after
}

///|
pub fn PolicyChange::summary(self : PolicyChange) -> String {
  let transition = if self.before.length() > 0 && self.after.length() > 0 {
    "`\{self.before}` -> `\{self.after}`"
  } else if self.after.length() > 0 {
    "`\{self.after}`"
  } else {
    "`\{self.before}`"
  }
  "\{self.kind.label()}: \{self.subject} \{transition}"
}

///|
/// Complete structural and optional behavioral difference.
pub struct PolicyDiff {
  changes : Array[PolicyChange]
  structural_count : Int
  behavioral_count : Int
} derive(Eq, Debug)

///|
pub fn PolicyDiff::changes(self : PolicyDiff) -> Array[PolicyChange] {
  self.changes
}

///|
pub fn PolicyDiff::structural_count(self : PolicyDiff) -> Int {
  self.structural_count
}

///|
pub fn PolicyDiff::behavioral_count(self : PolicyDiff) -> Int {
  self.behavioral_count
}

///|
pub fn PolicyDiff::is_empty(self : PolicyDiff) -> Bool {
  self.changes.length() == 0
}

///|
fn group_key(group : Group) -> String {
  join_strings(group.agents, ",")
}

///|
fn group_rule_key(group : Group, rule : Rule) -> String {
  "\{group_key(group)}|\{rule.kind.label()}|\{rule.normalized_pattern}"
}

///|
fn contains_group(policy : Policy, key : String) -> Bool {
  for group in policy.groups {
    if group_key(group) == key {
      return true
    }
  }
  false
}

///|
fn contains_rule(policy : Policy, key : String) -> Bool {
  for group in policy.groups {
    for rule in group.rules {
      if group_rule_key(group, rule) == key {
        return true
      }
    }
  }
  false
}

///|
fn find_group(policy : Policy, key : String) -> Group? {
  for group in policy.groups {
    if group_key(group) == key {
      return Some(group)
    }
  }
  None
}

///|
fn add_group_changes(
  before : Policy,
  after : Policy,
  output : Array[PolicyChange],
) -> Unit {
  for group in before.groups {
    let key = group_key(group)
    if !contains_group(after, key) {
      output.push({
        kind: GroupRemoved,
        subject: key,
        before: key,
        after: "",
        line_before: group.start_line,
        line_after: 0,
      })
    }
  }
  for group in after.groups {
    let key = group_key(group)
    if !contains_group(before, key) {
      output.push({
        kind: GroupAdded,
        subject: key,
        before: "",
        after: key,
        line_before: 0,
        line_after: group.start_line,
      })
    }
  }
}

///|
fn add_rule_changes(
  before : Policy,
  after : Policy,
  output : Array[PolicyChange],
) -> Unit {
  for group in before.groups {
    for rule in group.rules {
      let key = group_rule_key(group, rule)
      if !contains_rule(after, key) {
        output.push({
          kind: RuleRemoved,
          subject: group_key(group),
          before: "\{rule.kind.label()} \{rule.pattern}",
          after: "",
          line_before: rule.line,
          line_after: 0,
        })
      }
    }
  }
  for group in after.groups {
    for rule in group.rules {
      let key = group_rule_key(group, rule)
      if !contains_rule(before, key) {
        output.push({
          kind: RuleAdded,
          subject: group_key(group),
          before: "",
          after: "\{rule.kind.label()} \{rule.pattern}",
          line_before: 0,
          line_after: rule.line,
        })
      }
    }
  }
}

///|
fn add_string_set_changes(
  before : Array[String],
  after : Array[String],
  added_kind : ChangeKind,
  removed_kind : ChangeKind,
  subject : String,
  output : Array[PolicyChange],
) -> Unit {
  for value in before {
    if !array_contains_string(after, value) {
      output.push({
        kind: removed_kind,
        subject,
        before: value,
        after: "",
        line_before: 0,
        line_after: 0,
      })
    }
  }
  for value in after {
    if !array_contains_string(before, value) {
      output.push({
        kind: added_kind,
        subject,
        before: "",
        after: value,
        line_before: 0,
        line_after: 0,
      })
    }
  }
}

///|
fn add_delay_changes(
  before : Policy,
  after : Policy,
  output : Array[PolicyChange],
) -> Unit {
  for old_group in before.groups {
    let key = group_key(old_group)
    match find_group(after, key) {
      Some(new_group) =>
        if old_group.crawl_delay_millis != new_group.crawl_delay_millis {
          output.push({
            kind: DelayChanged,
            subject: key,
            before: "\{old_group.crawl_delay_millis}",
            after: "\{new_group.crawl_delay_millis}",
            line_before: old_group.start_line,
            line_after: new_group.start_line,
          })
        }
      None => ()
    }
  }
}

///|
fn add_behavior_changes(
  before : Policy,
  after : Policy,
  probes : Array[AccessProbe],
  output : Array[PolicyChange],
) -> Unit {
  for probe in probes {
    let old_decision = decide(before, probe.agent, probe.path)
    let new_decision = decide(after, probe.agent, probe.path)
    if old_decision.allowed != new_decision.allowed {
      output.push({
        kind: if new_decision.allowed {
          AccessBecameAllowed
        } else {
          AccessBecameDenied
        },
        subject: probe.name,
        before: old_decision.verdict(),
        after: new_decision.verdict(),
        line_before: old_decision.line,
        line_after: new_decision.line,
      })
    }
  }
}

///|
/// Compares policy structure and access behavior on caller-provided probes.
pub fn diff_policies(
  before : Policy,
  after : Policy,
  probes : Array[AccessProbe],
) -> PolicyDiff {
  let changes : Array[PolicyChange] = []
  add_group_changes(before, after, changes)
  add_rule_changes(before, after, changes)
  add_string_set_changes(
    before.sitemaps,
    after.sitemaps,
    SitemapAdded,
    SitemapRemoved,
    "sitemap",
    changes,
  )
  add_string_set_changes(
    before.hosts,
    after.hosts,
    HostAdded,
    HostRemoved,
    "host",
    changes,
  )
  add_delay_changes(before, after, changes)
  add_behavior_changes(before, after, probes, changes)
  let mut structural_count = 0
  let mut behavioral_count = 0
  for change in changes {
    if change.kind.is_behavioral() {
      behavioral_count = behavioral_count + 1
    } else {
      structural_count = structural_count + 1
    }
  }
  { changes, structural_count, behavioral_count }
}

///|
pub fn structural_diff(before : Policy, after : Policy) -> PolicyDiff {
  diff_policies(before, after, [])
}

///|
pub fn render_diff(diff : PolicyDiff) -> String {
  if diff.is_empty() {
    return "no policy changes\n"
  }
  let output = StringBuilder::new()
  output.write_string(
    "structural changes: \{diff.structural_count}, behavioral changes: \{diff.behavioral_count}\n",
  )
  for change in diff.changes {
    output.write_string("- ")
    output.write_string(change.summary())
    output.write_char('\n')
  }
  output.to_string()
}

///|
pub fn behavior_changes(diff : PolicyDiff) -> Array[PolicyChange] {
  let output : Array[PolicyChange] = []
  for change in diff.changes {
    if change.kind.is_behavioral() {
      output.push(change)
    }
  }
  output
}
