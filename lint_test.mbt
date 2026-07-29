///|
test "linter reports empty policies" {
  let diagnostics = @robots-gate.lint(@robots-gate.parse(""))
  inspect(
    @robots-gate.has_diagnostic_code(diagnostics, "LNT001"),
    content="true",
  )
}

///|
test "linter reports missing wildcard fallback" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: Bot
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT002"),
    content="true",
  )
}

///|
test "strict linter asks for a sitemap" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let diagnostics = @robots-gate.lint_with_options(
    policy,
    @robots-gate.strict_lint_options(),
  )
  inspect(
    @robots-gate.has_diagnostic_code(diagnostics, "LNT003"),
    content="true",
  )
}

///|
test "linter finds empty groups" {
  let policy = @robots-gate.parse("User-agent: *")
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT004"),
    content="true",
  )
}

///|
test "linter warns about large crawl delays" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Crawl-delay: 120
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT006"),
    content="true",
  )
}

///|
test "linter warns about wildcard mixed with named agents" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|User-agent: Bot
      #|Disallow: /private
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT007"),
    content="true",
  )
}

///|
test "linter detects global block all" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT008"),
    content="true",
  )
}

///|
test "linter detects malformed percent encoding" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /bad%2
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT012"),
    content="true",
  )
}

///|
test "linter detects non-terminal dollar anchors" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /download$/more
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT013"),
    content="true",
  )
}

///|
test "linter detects redundant trailing wildcard" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /tmp/*
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT014"),
    content="true",
  )
}

///|
test "linter detects duplicate rules" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /tmp
      #|Disallow: /tmp
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT016"),
    content="true",
  )
}

///|
test "linter detects equivalent allow disallow conflicts" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /same
      #|Allow: /same
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT017"),
    content="true",
  )
}

///|
test "linter reports unknown directives" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Request-rate: 1/10
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(@robots-gate.lint(policy), "LNT019"),
    content="true",
  )
}

///|
test "diagnostic severity filtering keeps warnings and errors" {
  let policy = @robots-gate.parse("not-a-record")
  let filtered = @robots-gate.diagnostics_at_least(
    @robots-gate.all_diagnostics(policy),
    @robots-gate.Warning,
  )
  inspect(filtered.length() > 0, content="true")
}
