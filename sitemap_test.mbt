///|
test "sitemap parser reads XML urlsets" {
  let document = @robots-gate.parse_sitemap(
    (
      #|<?xml version="1.0"?>
      #|<urlset>
      #|  <url><loc>https://example.com/</loc></url>
      #|  <url><loc>https://example.com/docs</loc></url>
      #|</urlset>
    ),
  )
  inspect(document.kind().label(), content="urlset")
  inspect(document.entry_count(), content="2")
}

///|
test "sitemap parser decodes XML entities" {
  let document = @robots-gate.parse_sitemap(
    "<urlset><url><loc>https://example.com/a?x=1&amp;y=2</loc></url></urlset>",
  )
  inspect(
    document.entries()[0].location(),
    content="https://example.com/a?x=1&y=2",
  )
}

///|
test "sitemap parser reads metadata" {
  let document = @robots-gate.parse_sitemap(
    (
      #|<urlset><url>
      #|<loc>https://example.com/docs</loc>
      #|<lastmod>2026-07-29</lastmod>
      #|<changefreq>weekly</changefreq>
      #|<priority>0.8</priority>
      #|</url></urlset>
    ),
  )
  inspect(document.entries()[0].priority_millis(), content="800")
  inspect(document.entries()[0].has_last_modified(), content="true")
}

///|
test "sitemap parser reads indexes" {
  let document = @robots-gate.parse_sitemap(
    (
      #|<sitemapindex>
      #|<sitemap><loc>https://example.com/a.xml</loc></sitemap>
      #|<sitemap><loc>https://example.com/b.xml</loc></sitemap>
      #|</sitemapindex>
    ),
  )
  inspect(document.kind().label(), content="sitemap-index")
  inspect(document.child_count(), content="2")
}

///|
test "sitemap parser reads text format" {
  let document = @robots-gate.parse_sitemap(
    (
      #|# generated
      #|https://example.com/
      #|https://example.com/docs
    ),
  )
  inspect(document.kind().label(), content="text")
  inspect(document.entry_count(), content="2")
}

///|
test "sitemap parser rejects unknown XML" {
  let document = @robots-gate.parse_sitemap("<feed></feed>")
  inspect(document.kind().label(), content="unknown")
  inspect(document.is_valid(), content="false")
}

///|
test "sitemap parser reports duplicate URLs" {
  let document = @robots-gate.parse_sitemap(
    (
      #|https://example.com/a
      #|https://EXAMPLE.com/a
    ),
  )
  inspect(
    @robots-gate.has_diagnostic_code(document.diagnostics(), "SMP003"),
    content="true",
  )
}

///|
test "sitemap parser validates priority" {
  let document = @robots-gate.parse_sitemap(
    "<urlset><url><loc>https://example.com/</loc><priority>1.5</priority></url></urlset>",
  )
  inspect(
    @robots-gate.has_diagnostic_code(document.diagnostics(), "SMP006"),
    content="true",
  )
}

///|
test "sitemap entries can be filtered by robots policy" {
  let policy = @robots-gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private
    ),
  )
  let document = @robots-gate.parse_sitemap(
    (
      #|https://example.com/
      #|https://example.com/private/report
    ),
  )
  inspect(
    @robots-gate.allowed_sitemap_entries(policy, "bot", document).length(),
    content="1",
  )
  inspect(
    @robots-gate.blocked_sitemap_entries(policy, "bot", document).length(),
    content="1",
  )
}

///|
test "sitemap audit finds cross-origin entries" {
  let document = @robots-gate.parse_sitemap(
    (
      #|https://example.com/
      #|https://cdn.example.net/asset
    ),
  )
  inspect(
    @robots-gate.cross_origin_entries(document, "https://example.com/").length(),
    content="1",
  )
}

///|
test "sitemap entries become crawl tasks" {
  let document = @robots-gate.parse_sitemap(
    "<urlset><url><loc>https://example.com/docs</loc><priority>0.9</priority></url></urlset>",
  )
  let tasks = @robots-gate.tasks_from_sitemap(document, 2048)
  inspect(tasks.length(), content="1")
  inspect(tasks[0].priority(), content="900")
  inspect(tasks[0].estimated_bytes(), content="2048")
}
