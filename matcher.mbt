///|
fn agent_match_length(pattern : String, agent : String) -> Int {
  if pattern == "*" {
    1
  } else if agent.contains(pattern) {
    pattern.length()
  } else {
    -1
  }
}

///|
fn best_agent_specificity(groups : Array[Group], agent : String) -> Int {
  let mut best = -1
  for group in groups {
    for group_agent in group.agents {
      let specificity = agent_match_length(group_agent, agent)
      if specificity > best {
        best = specificity
      }
    }
  }
  best
}

///|
fn group_matches_specificity(
  group : Group,
  agent : String,
  specificity : Int,
) -> Bool {
  for group_agent in group.agents {
    if agent_match_length(group_agent, agent) == specificity {
      return true
    }
  }
  false
}

///|
fn wildcard_match(
  pattern : Array[Char],
  p_index : Int,
  path : Array[Char],
  s_index : Int,
  exact_end : Bool,
) -> Bool {
  if p_index == pattern.length() {
    return if exact_end { s_index == path.length() } else { true }
  }
  if pattern[p_index] == '*' {
    for next = s_index; next <= path.length(); next = next + 1 {
      if wildcard_match(pattern, p_index + 1, path, next, exact_end) {
        return true
      }
    }
    false
  } else if s_index < path.length() && pattern[p_index] == path[s_index] {
    wildcard_match(pattern, p_index + 1, path, s_index + 1, exact_end)
  } else {
    false
  }
}

///|
fn pattern_matches(pattern : String, path : String) -> Bool {
  let chars = pattern.to_array()
  if chars.length() > 0 && chars[chars.length() - 1] == '$' {
    let trimmed = String::from_array(chars[0:chars.length() - 1])
    wildcard_match(trimmed.to_array(), 0, path.to_array(), 0, true)
  } else {
    wildcard_match(chars, 0, path.to_array(), 0, false)
  }
}

///|
fn default_allow(
  agent : String,
  path : String,
  normalized_path : String,
  reason : String,
  agent_specificity : Int,
  matched_groups : Int,
  trace : Array[DecisionStep],
) -> Decision {
  {
    allowed: true,
    agent,
    path,
    normalized_path,
    rule_kind: Allow,
    rule_pattern: "",
    line: 0,
    reason,
    agent_specificity,
    rule_specificity: 0,
    matched_groups,
    trace,
  }
}

///|
/// Returns the full matching decision for a user-agent and URL path.
pub fn decide(policy : Policy, agent : String, path : String) -> Decision {
  let normalized_agent = lower_ascii(agent)
  let normalized_path = normalize_path(path)
  let trace : Array[DecisionStep] = []
  trace.push({
    stage: "normalize",
    detail: "agent `\{normalized_agent}`, path `\{normalized_path}`",
  })
  if normalized_path == "/robots.txt" {
    trace.push({
      stage: "implicit",
      detail: "RFC 9309 implicitly allows /robots.txt",
    })
    return default_allow(
      agent, path, normalized_path, "robots.txt is implicitly allowed", 0, 0, trace,
    )
  }
  let agent_specificity = best_agent_specificity(
    policy.groups,
    normalized_agent,
  )
  if agent_specificity < 0 {
    trace.push({ stage: "group", detail: "no user-agent group matched" })
    return default_allow(
      agent, path, normalized_path, "no matching user-agent group", -1, 0, trace,
    )
  }
  let mut matched_groups = 0
  let mut best_rule : Rule? = None
  let mut best_specificity = -1
  let mut best_allow = false
  for group in policy.groups {
    if group_matches_specificity(group, normalized_agent, agent_specificity) {
      matched_groups = matched_groups + 1
      for rule in group.rules {
        if rule.pattern.length() > 0 &&
          pattern_matches(rule.normalized_pattern, normalized_path) {
          let specificity = rule.specificity()
          let allow = rule.kind == Allow
          if specificity > best_specificity ||
            (specificity == best_specificity && allow && !best_allow) {
            best_rule = Some(rule)
            best_specificity = specificity
            best_allow = allow
          }
        }
      }
    }
  }
  trace.push({
    stage: "group",
    detail: "\{matched_groups} group(s) matched at specificity \{agent_specificity}",
  })
  match best_rule {
    None => {
      trace.push({ stage: "rule", detail: "no path rule matched" })
      default_allow(
        agent, path, normalized_path, "matching group has no matching path rule",
        agent_specificity, matched_groups, trace,
      )
    }
    Some(rule) => {
      trace.push({
        stage: "rule",
        detail: "\{rule.kind.label()} `\{rule.pattern}` at line \{rule.line}",
      })
      {
        allowed: rule.kind == Allow,
        agent,
        path,
        normalized_path,
        rule_kind: rule.kind,
        rule_pattern: rule.pattern,
        line: rule.line,
        reason: "most specific matching robots.txt rule",
        agent_specificity,
        rule_specificity: best_specificity,
        matched_groups,
        trace,
      }
    }
  }
}

///|
/// Convenience helper that returns only the allow/deny boolean.
pub fn can_fetch(policy : Policy, agent : String, path : String) -> Bool {
  decide(policy, agent, path).allowed()
}

///|
/// Returns the applicable crawl delay in milliseconds, or -1 when absent.
pub fn crawl_delay(policy : Policy, agent : String) -> Int {
  let normalized_agent = lower_ascii(agent)
  let specificity = best_agent_specificity(policy.groups, normalized_agent)
  if specificity < 0 {
    return -1
  }
  let mut delay = -1
  for group in policy.groups {
    if group_matches_specificity(group, normalized_agent, specificity) &&
      group.crawl_delay_millis >= 0 {
      if delay < 0 || group.crawl_delay_millis > delay {
        delay = group.crawl_delay_millis
      }
    }
  }
  delay
}

///|
/// Returns every effective rule from equally specific matching groups.
pub fn effective_rules(policy : Policy, agent : String) -> Array[Rule] {
  let result : Array[Rule] = []
  let normalized_agent = lower_ascii(agent)
  let specificity = best_agent_specificity(policy.groups, normalized_agent)
  if specificity < 0 {
    return result
  }
  for group in policy.groups {
    if group_matches_specificity(group, normalized_agent, specificity) {
      for rule in group.rules {
        result.push(rule)
      }
    }
  }
  result
}
