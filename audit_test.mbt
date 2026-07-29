///|
test "audit aggregates policy and matrix" {
  let result = @robots-gate.audit(
    (
      #|User-agent: *
      #|Disallow: /private
    ),
    ["bot"],
    ["/", "/private"],
  )
  inspect(result.matrix().total(), content="2")
  inspect(result.explicit_decisions(), content="1")
  inspect(result.default_decisions(), content="1")
}

///|
test "audit score stays within bounds" {
  let result = @robots-gate.audit_default("not a policy")
  inspect(result.risk_score() >= 0, content="true")
  inspect(result.risk_score() <= 100, content="true")
}

///|
test "clean audit receives a passing result" {
  let result = @robots-gate.audit(
    (
      #|User-agent: *
      #|Allow: /
      #|Sitemap: https://example.com/sitemap.xml
    ),
    ["bot"],
    ["/"],
  )
  inspect(result.passed(), content="true")
  inspect(@robots-gate.audit_exit_code(result), content="0")
}

///|
test "audit Markdown includes matrix" {
  let result = @robots-gate.audit_default(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let markdown = @robots-gate.render_audit_markdown(result)
  inspect(markdown.contains("# MoonRobots Gate audit"), content="true")
  inspect(markdown.contains("## Access matrix"), content="true")
}

///|
test "audit JSON includes stable top-level fields" {
  let result = @robots-gate.audit_default(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let json = @robots-gate.render_audit_json(result)
  inspect(json.contains("\"risk_score\":"), content="true")
  inspect(json.contains("\"probes\":"), content="true")
}

///|
test "audit JSON escapes diagnostic messages" {
  let result = @robots-gate.audit_default("un\"known: value")
  let json = @robots-gate.render_audit_json(result)
  inspect(json.contains("\\\""), content="true")
}
