///|
fn main {
  let policy = @gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
    ),
  )
  let document = @gate.parse_sitemap(
    (
      #|<urlset>
      #|<url><loc>https://example.com/</loc></url>
      #|<url><loc>https://example.com/docs</loc></url>
      #|<url><loc>https://example.com/private/report</loc></url>
      #|</urlset>
    ),
  )
  println(@gate.render_sitemap_summary(document))
  println(@gate.render_blocked_sitemap_report(policy, "ExampleBot", document))
}
