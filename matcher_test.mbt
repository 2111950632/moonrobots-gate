///|
test "matcher combines equally specific groups" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: ExampleBot
      #|Disallow: /private
      #|User-agent: ExampleBot
      #|Allow: /private/public
    ),
  )
  let decision = @robots-gate.decide(
    policy, "ExampleBot/2.0", "/private/public/page",
  )
  inspect(decision.allowed(), content="true")
  inspect(decision.matched_groups(), content="2")
}

///|
test "matcher does not merge wildcard with a named group" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
      #|User-agent: NamedBot
      #|Allow: /
    ),
  )
  inspect(
    @robots-gate.can_fetch(policy, "NamedBot", "/anything"),
    content="true",
  )
}

///|
test "matcher implicitly allows robots.txt" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
    ),
  )
  let decision = @robots-gate.decide(policy, "bot", "/robots.txt")
  inspect(decision.allowed(), content="true")
  inspect(decision.line(), content="0")
}

///|
test "matcher decodes unreserved percent octets" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /foo/bar
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/foo/%62ar"), content="false")
}

///|
test "matcher preserves reserved percent octets" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /foo%2Fbar
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/foo%2fbar"), content="false")
  inspect(@robots-gate.can_fetch(policy, "bot", "/foo/bar"), content="true")
}

///|
test "matcher normalizes missing leading slash" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private
    ),
  )
  let decision = @robots-gate.decide(policy, "bot", "private/page")
  inspect(decision.allowed(), content="false")
  inspect(decision.normalized_path(), content="/private/page")
}

///|
test "matcher supports zero-length wildcard expansion" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /a*b
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/ab"), content="false")
}

///|
test "matcher uses case-sensitive paths" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /Private
    ),
  )
  inspect(@robots-gate.can_fetch(policy, "bot", "/private"), content="true")
}

///|
test "matcher exposes effective rules" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: Bot
      #|Disallow: /a
      #|User-agent: Bot
      #|Allow: /a/public
    ),
  )
  inspect(@robots-gate.effective_rules(policy, "Bot").length(), content="2")
}

///|
test "matcher chooses conservative maximum crawl delay across merged groups" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: Bot
      #|Crawl-delay: 1
      #|User-agent: Bot
      #|Crawl-delay: 3
    ),
  )
  inspect(@robots-gate.crawl_delay(policy, "Bot"), content="3000")
}

///|
test "matcher records an explanation trace" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
    ),
  )
  let decision = @robots-gate.decide(policy, "bot", "/docs")
  inspect(decision.trace().length(), content="3")
  inspect(decision.agent_specificity(), content="1")
}

///|
test "matcher chooses allow for equal specificity" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /same
      #|Allow: /same
    ),
  )
  let decision = @robots-gate.decide(policy, "bot", "/same")
  inspect(decision.allowed(), content="true")
  inspect(decision.line(), content="3")
}
