///|
fn main {
  let policy = @gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
      #|Allow: /private/public
    ),
  )
  println(@gate.decide(policy, "bot", "/private/secret").summary())
  println(@gate.decide(policy, "bot", "/private/public/index.html").summary())
  println(@gate.decide(policy, "bot", "/docs/index.html").summary())
}
