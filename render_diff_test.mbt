///|
test "canonical renderer normalizes field spelling" {
  let policy = @robots-gate.parse(
    (
      #|USER-AGENT: *
      #|DISALLOW: /private
    ),
  )
  inspect(
    @robots-gate.render_policy(policy, @robots-gate.Canonical),
    content="User-agent: *\nDisallow: /private\n",
  )
}

///|
test "compact renderer omits spaces after colons" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.compact_policy(policy),
    content="User-agent:*\nAllow:/\n",
  )
}

///|
test "annotated renderer includes source lines" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.annotated_policy(policy).contains(
      "# group from source lines 1-2",
    ),
    content="true",
  )
}

///|
test "renderer formats fractional crawl delays" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Crawl-delay: 1.25
    ),
  )
  inspect(
    @robots-gate.render_policy(policy, @robots-gate.Canonical).contains(
      "Crawl-delay: 1.25",
    ),
    content="true",
  )
}

///|
test "structural diff finds added rules" {
  let before = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let after = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
      #|Disallow: /private
    ),
  )
  let diff = @robots-gate.structural_diff(before, after)
  inspect(diff.structural_count(), content="1")
  inspect(diff.changes()[0].kind().label(), content="rule-added")
}

///|
test "policy diff finds sitemap changes" {
  let before = @robots-gate.parse("")
  let after = @robots-gate.parse("Sitemap: https://example.com/map.xml")
  let diff = @robots-gate.structural_diff(before, after)
  inspect(diff.changes()[0].kind().label(), content="sitemap-added")
}

///|
test "policy diff detects access becoming denied" {
  let before = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let after = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private
    ),
  )
  let probes = [@robots-gate.access_probe("private", "bot", "/private")]
  let diff = @robots-gate.diff_policies(before, after, probes)
  inspect(diff.behavioral_count(), content="1")
  inspect(
    @robots-gate.behavior_changes(diff)[0].kind().label(),
    content="access-became-denied",
  )
}

///|
test "policy diff can be empty" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.structural_diff(policy, policy).is_empty(),
    content="true",
  )
}

///|
test "matrix builds an agent path grid" {
  let probes = @robots-gate.build_probe_grid(["BotA", "BotB"], ["/", "/private"])
  inspect(probes.length(), content="4")
}

///|
test "matrix counts allow deny and default outcomes" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private
    ),
  )
  let matrix = @robots-gate.run_matrix(policy, [
    @robots-gate.access_probe("home", "bot", "/"),
    @robots-gate.access_probe("private", "bot", "/private"),
  ])
  inspect(matrix.allowed_count(), content="1")
  inspect(matrix.denied_count(), content="1")
  inspect(matrix.default_count(), content="1")
}

///|
test "matrix comparison counts behavior flips" {
  let allow = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let deny = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
    ),
  )
  let probes = [@robots-gate.access_probe("root", "bot", "/")]
  let comparison = @robots-gate.compare_matrices(
    @robots-gate.run_matrix(allow, probes),
    @robots-gate.run_matrix(deny, probes),
  )
  inspect(@robots-gate.behavior_flip_count(comparison), content="1")
}

///|
test "matrix renders Markdown and CSV" {
  let matrix = @robots-gate.run_matrix(@robots-gate.parse(""), [
    @robots-gate.access_probe("root", "bot", "/"),
  ])
  inspect(
    @robots-gate.render_matrix_markdown(matrix).contains("| Probe |"),
    content="true",
  )
  inspect(
    @robots-gate.render_matrix_csv(matrix).has_prefix("probe,agent"),
    content="true",
  )
}

///|
test "render style parser accepts supported styles" {
  inspect(@robots-gate.parse_render_style("compact").unwrap(), content="Compact")
  inspect(
    @robots-gate.parse_render_style("annotated").unwrap(),
    content="Annotated",
  )
}

///|
test "render style parser rejects unknown styles" {
  match @robots-gate.parse_render_style("pretty") {
    Ok(_) => inspect("ok", content="error")
    Err(message) => inspect(message, content="unknown render style: pretty")
  }
}
