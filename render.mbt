///|
/// Formatting style for normalized robots.txt output.
pub(all) enum RenderStyle {
  Canonical
  Compact
  Annotated
} derive(Eq, Debug)

///|
pub fn RenderStyle::label(self : RenderStyle) -> String {
  match self {
    Canonical => "canonical"
    Compact => "compact"
    Annotated => "annotated"
  }
}

///|
fn three_digits(value : Int) -> String {
  if value < 10 {
    "00\{value}"
  } else if value < 100 {
    "0\{value}"
  } else {
    "\{value}"
  }
}

///|
fn format_delay(millis : Int) -> String {
  if millis < 0 {
    ""
  } else if millis % 1000 == 0 {
    "\{millis / 1000}"
  } else {
    let seconds = millis / 1000
    let fraction = millis % 1000
    let full = three_digits(fraction)
    if full.has_suffix("00") {
      "\{seconds}.\{string_slice(full, 0, 1)}"
    } else if full.has_suffix("0") {
      "\{seconds}.\{string_slice(full, 0, 2)}"
    } else {
      "\{seconds}.\{full}"
    }
  }
}

///|
fn write_record(
  output : StringBuilder,
  key : String,
  value : String,
  style : RenderStyle,
) -> Unit {
  output.write_string(key)
  if style == Compact {
    output.write_string(":")
  } else {
    output.write_string(": ")
  }
  output.write_string(value)
  output.write_char('\n')
}

///|
fn render_group(group : Group, style : RenderStyle) -> String {
  let output = StringBuilder::new()
  if style == Annotated {
    output.write_string("# group from source lines ")
    output.write_string("\{group.start_line}-\{group.end_line}\n")
  }
  for agent in group.agents {
    write_record(output, "User-agent", agent, style)
  }
  if group.crawl_delay_millis >= 0 {
    write_record(
      output,
      "Crawl-delay",
      format_delay(group.crawl_delay_millis),
      style,
    )
  }
  for rule in group.rules {
    write_record(output, rule.kind.directive_name(), rule.pattern, style)
  }
  output.to_string()
}

///|
fn render_unknown_directives(policy : Policy, style : RenderStyle) -> String {
  let output = StringBuilder::new()
  for directive in policy.directives {
    if directive.kind == UnknownDirective ||
      directive.kind == CleanParamDirective {
      write_record(output, directive.key, directive.value, style)
    }
  }
  output.to_string()
}

///|
/// Serializes the semantic policy into deterministic robots.txt text.
pub fn render_policy(policy : Policy, style : RenderStyle) -> String {
  let output = StringBuilder::new()
  for index, group in policy.groups {
    if index > 0 && style != Compact {
      output.write_char('\n')
    }
    output.write_string(render_group(group, style))
  }
  if policy.hosts.length() > 0 ||
    policy.sitemaps.length() > 0 ||
    render_unknown_directives(policy, style).length() > 0 {
    if policy.groups.length() > 0 && style != Compact {
      output.write_char('\n')
    }
  }
  for host in policy.hosts {
    write_record(output, "Host", host, style)
  }
  for sitemap in policy.sitemaps {
    write_record(output, "Sitemap", sitemap, style)
  }
  output.write_string(render_unknown_directives(policy, style))
  output.to_string()
}

///|
pub fn canonicalize(input : String) -> String {
  render_policy(parse(input), Canonical)
}

///|
pub fn compact_policy(policy : Policy) -> String {
  render_policy(policy, Compact)
}

///|
pub fn annotated_policy(policy : Policy) -> String {
  render_policy(policy, Annotated)
}

///|
pub fn render_diagnostics(diagnostics : Array[Diagnostic]) -> String {
  let output = StringBuilder::new()
  for diagnostic in diagnostics {
    output.write_string(diagnostic.summary())
    output.write_char('\n')
    if diagnostic.hint.length() > 0 {
      output.write_string("  hint: ")
      output.write_string(diagnostic.hint)
      output.write_char('\n')
    }
  }
  output.to_string()
}

///|
pub fn render_decision_trace(decision : Decision) -> String {
  let output = StringBuilder::new()
  output.write_string(decision.summary())
  output.write_char('\n')
  for step in decision.trace {
    output.write_string("  - ")
    output.write_string(step.summary())
    output.write_char('\n')
  }
  output.to_string()
}

///|
pub fn render_policy_summary(policy : Policy) -> String {
  let stats = policy.stats()
  let output = StringBuilder::new()
  output.write_string("groups: \{stats.groups}\n")
  output.write_string("agents: \{stats.agents}\n")
  output.write_string("rules: \{stats.rules}\n")
  output.write_string("allows: \{stats.allows}\n")
  output.write_string("disallows: \{stats.disallows}\n")
  output.write_string("sitemaps: \{stats.sitemaps}\n")
  output.write_string("parse diagnostics: \{stats.diagnostics}\n")
  output.to_string()
}

///|
pub fn parse_render_style(input : String) -> Result[RenderStyle, String] {
  match input {
    "canonical" => Ok(Canonical)
    "compact" => Ok(Compact)
    "annotated" => Ok(Annotated)
    _ => Err("unknown render style: \{input}")
  }
}
