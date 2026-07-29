///|
fn main {
  let policy = @gate.parse(
    (
      #|User-agent: *
      #|Disallow: /
      #|Allow: /public/
      #|
      #|User-agent: ResearchBot
      #|Disallow: /tmp/*.json
      #|Allow: /tmp/public
      #|Sitemap: https://example.com/sitemap.xml
    ),
  )
  println("groups=\{policy.group_count()} rules=\{policy.rule_count()}")
  for
    path in ["/", "/public/index.html", "/tmp/audit.json", "/tmp/public/readme"] {
    println(@gate.decide(policy, "ResearchBot/2.0", path).summary())
  }
}
