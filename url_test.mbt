///|
test "URL parser reads HTTPS origin and path" {
  let url = @robots-gate.parse_url("https://Example.COM/docs?q=1")
  inspect(url.valid(), content="true")
  inspect(url.origin(), content="https://example.com")
  inspect(url.path_query(), content="/docs?q=1")
}

///|
test "URL parser removes default ports" {
  let url = @robots-gate.parse_url("https://example.com:443/a")
  inspect(url.origin(), content="https://example.com")
}

///|
test "URL parser preserves non-default ports" {
  let url = @robots-gate.parse_url("http://example.com:8080/a")
  inspect(url.origin(), content="http://example.com:8080")
}

///|
test "URL parser handles query without explicit path" {
  let url = @robots-gate.parse_url("https://example.com?q=1")
  inspect(url.path_query(), content="/?q=1")
}

///|
test "URL parser separates fragments" {
  let url = @robots-gate.parse_url("https://example.com/a#part")
  inspect(url.fragment(), content="part")
  inspect(url.without_fragment(), content="https://example.com/a")
}

///|
test "URL parser rejects unsupported schemes" {
  let url = @robots-gate.parse_url("ftp://example.com/a")
  inspect(url.valid(), content="false")
}

///|
test "URL parser rejects userinfo" {
  let url = @robots-gate.parse_url("https://user@example.com/a")
  inspect(url.valid(), content="false")
}

///|
test "URL parser rejects invalid ports" {
  let url = @robots-gate.parse_url("https://example.com:99999/a")
  inspect(url.valid(), content="false")
}

///|
test "URL helpers compare origins" {
  inspect(
    @robots-gate.same_origin("https://example.com/a", "https://EXAMPLE.com/b"),
    content="true",
  )
}

///|
test "URL helper creates robots location" {
  inspect(
    @robots-gate.robots_url_for("https://example.com/docs"),
    content="https://example.com/robots.txt",
  )
}

///|
test "URL helper calculates path depth" {
  inspect(@robots-gate.url_depth("https://example.com/a/b/c?q=1"), content="3")
}

///|
test "URL canonicalization uppercases reserved percent encoding" {
  inspect(
    @robots-gate.canonical_url("https://EXAMPLE.com/a%2fb#x"),
    content="https://example.com/a%2Fb",
  )
}
