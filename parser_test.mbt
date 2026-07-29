///|
test "parser strips a UTF-8 BOM" {
  let policy = @robots-gate.parse("\u{FEFF}User-agent: *\nDisallow: /private")
  inspect(policy.group_count(), content="1")
  inspect(policy.groups()[0].agents()[0], content="*")
}

///|
test "parser accepts CRLF input" {
  let policy = @robots-gate.parse("User-agent: *\r\nDisallow: /tmp\r\n")
  inspect(policy.rule_count(), content="1")
  inspect(policy.groups()[0].rules()[0].pattern(), content="/tmp")
}

///|
test "parser ignores rules before first agent" {
  let policy = @robots-gate.parse(
    (
      #|Disallow: /orphan
      #|User-agent: *
      #|Allow: /
    ),
  )
  inspect(policy.rule_count(), content="1")
  inspect(
    @robots-gate.has_diagnostic_code(policy.diagnostics(), "RBT009"),
    content="true",
  )
}

///|
test "parser merges consecutive agent records into one group" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: BotA
      #|User-agent: BotB
      #|Disallow: /shared
    ),
  )
  inspect(policy.group_count(), content="1")
  inspect(policy.groups()[0].agent_count(), content="2")
}

///|
test "parser starts a new group after rules" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: BotA
      #|Disallow: /a
      #|User-agent: BotB
      #|Disallow: /b
    ),
  )
  inspect(policy.group_count(), content="2")
  inspect(policy.groups()[1].start_line(), content="3")
}

///|
test "parser reads fractional crawl delay" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Crawl-delay: 1.25
    ),
  )
  inspect(policy.groups()[0].crawl_delay_millis(), content="1250")
  inspect(@robots-gate.crawl_delay(policy, "AnyBot"), content="1250")
}

///|
test "parser reports invalid crawl delay" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Crawl-delay: fast
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(policy.diagnostics(), "RBT018"),
    content="true",
  )
  inspect(policy.groups()[0].has_crawl_delay(), content="false")
}

///|
test "parser preserves unknown directives" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Visit-time: 0100-0500
    ),
  )
  inspect(policy.directives().length(), content="2")
  inspect(policy.directives()[1].kind().label(), content="unknown")
}

///|
test "parser deduplicates sitemap values" {
  let policy = @robots-gate.parse(
    (
      #|Sitemap: https://example.com/sitemap.xml
      #|Sitemap: https://example.com/sitemap.xml
    ),
  )
  inspect(policy.sitemaps().length(), content="1")
  inspect(
    @robots-gate.has_diagnostic_code(policy.diagnostics(), "RBT016"),
    content="true",
  )
}

///|
test "parser validates sitemap shape" {
  let policy = @robots-gate.parse("Sitemap: /sitemap.xml")
  inspect(
    @robots-gate.has_diagnostic_code(policy.diagnostics(), "RBT015"),
    content="true",
  )
}

///|
test "parser captures host extensions" {
  let policy = @robots-gate.parse(
    (
      #|Host: WWW.Example.COM
      #|Host: www.example.com
    ),
  )
  inspect(policy.hosts().length(), content="1")
  inspect(policy.hosts()[0], content="www.example.com")
}

///|
test "parser reports lines without colons" {
  let policy = @robots-gate.parse("this is not a directive")
  inspect(
    @robots-gate.has_diagnostic_code(policy.diagnostics(), "RBT005"),
    content="true",
  )
}

///|
test "parser applies input character limits" {
  let options = @robots-gate.parse_options(4, 10, 20, 10, 10, true)
  let policy = @robots-gate.parse_with_options("User-agent: *", options)
  inspect(policy.truncated(), content="true")
  inspect(policy.error_count(), content="1")
}

///|
test "parser applies line limits" {
  let options = @robots-gate.parse_options(1000, 1, 100, 10, 10, true)
  let policy = @robots-gate.parse_with_options(
    "User-agent: *\nDisallow: /private", options,
  )
  inspect(policy.truncated(), content="true")
  inspect(policy.rule_count(), content="0")
}
