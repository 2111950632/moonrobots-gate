///|
test "parses groups rules and sitemap" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
      #|Allow: /private/public
      #|Sitemap: https://example.com/sitemap.xml
    ),
  )
  inspect(policy.group_count(), content="1")
  inspect(policy.rule_count(), content="2")
  inspect(policy.sitemaps()[0], content="https://example.com/sitemap.xml")
}

///|
test "allows by default when no rule matches" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/index.html"), content="true")
}

///|
test "denies matching disallow rule" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /admin
    ),
  )
  let decision = @robots-gate.decide(policy, "ExampleBot", "/admin/panel")
  inspect(decision.allowed(), content="false")
  inspect(decision.line(), content="2")
  inspect(decision.rule_pattern(), content="/admin")
}

///|
test "longer allow wins over shorter disallow" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
      #|Allow: /private/public
    ),
  )
  inspect(
    @robots-gate.can_fetch(policy, "bot", "/private/public/page.html"),
    content="true",
  )
  inspect(
    @robots-gate.can_fetch(policy, "bot", "/private/secret"),
    content="false",
  )
}

///|
test "specific user agent wins over wildcard" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
      #|
      #|User-agent: ExampleBot
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.can_fetch(policy, "ExampleBot/1.0", "/docs"),
    content="true",
  )
  inspect(@robots-gate.can_fetch(policy, "OtherBot", "/docs"), content="false")
}

///|
test "wildcards match variable path segments" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /tmp/*.json
    ),
  )
  inspect(
    @robots-gate.can_fetch(policy, "bot", "/tmp/a/report.json"),
    content="false",
  )
  inspect(
    @robots-gate.can_fetch(policy, "bot", "/tmp/a/report.txt"),
    content="true",
  )
}

///|
test "dollar anchors to end of path" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /download$
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/download"), content="false")
  inspect(
    @robots-gate.can_fetch(policy, "bot", "/download/file"),
    content="true",
  )
}

///|
test "empty disallow does not block" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow:
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/anything"), content="true")
}

///|
test "comments and case are normalized" {
  let policy = @robots-gate.parse(
    (
      #|USER-AGENT: SampleBot # inline comment
      #|DISALLOW: /Case
    ),
  )
  inspect(
    @robots-gate.can_fetch(policy, "samplebot", "/Case/file"),
    content="false",
  )
  inspect(policy.groups()[0].agents()[0], content="samplebot")
}

///|
test "decision summary is stable" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /public
    ),
  )
  inspect(
    @robots-gate.decide(policy, "bot", "/public/index.html").summary(),
    content="ALLOW bot /public/index.html via allow `/public` at line 2",
  )
}
