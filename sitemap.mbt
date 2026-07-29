///|
/// Detected sitemap representation.
pub(all) enum SitemapKind {
  UrlSet
  SitemapIndex
  TextSitemap
  UnknownSitemap
} derive(Eq, Debug)

///|
pub fn SitemapKind::label(self : SitemapKind) -> String {
  match self {
    UrlSet => "urlset"
    SitemapIndex => "sitemap-index"
    TextSitemap => "text"
    UnknownSitemap => "unknown"
  }
}

///|
/// One URL from a sitemap document.
pub struct SitemapEntry {
  location : String
  last_modified : String
  change_frequency : String
  priority_millis : Int
  ordinal : Int
} derive(Eq, Debug)

///|
pub fn SitemapEntry::location(self : SitemapEntry) -> String {
  self.location
}

///|
pub fn SitemapEntry::last_modified(self : SitemapEntry) -> String {
  self.last_modified
}

///|
pub fn SitemapEntry::change_frequency(self : SitemapEntry) -> String {
  self.change_frequency
}

///|
pub fn SitemapEntry::priority_millis(self : SitemapEntry) -> Int {
  self.priority_millis
}

///|
pub fn SitemapEntry::ordinal(self : SitemapEntry) -> Int {
  self.ordinal
}

///|
pub fn SitemapEntry::has_last_modified(self : SitemapEntry) -> Bool {
  self.last_modified.length() > 0
}

///|
pub fn SitemapEntry::has_priority(self : SitemapEntry) -> Bool {
  self.priority_millis >= 0
}

///|
pub fn SitemapEntry::path(self : SitemapEntry) -> String {
  url_path(self.location)
}

///|
/// Parsed sitemap entries, child indexes, and diagnostics.
pub struct SitemapDocument {
  kind : SitemapKind
  entries : Array[SitemapEntry]
  child_sitemaps : Array[String]
  diagnostics : Array[Diagnostic]
  source_items : Int
} derive(Eq, Debug)

///|
pub fn SitemapDocument::kind(self : SitemapDocument) -> SitemapKind {
  self.kind
}

///|
pub fn SitemapDocument::entries(self : SitemapDocument) -> Array[SitemapEntry] {
  self.entries
}

///|
pub fn SitemapDocument::child_sitemaps(self : SitemapDocument) -> Array[String] {
  self.child_sitemaps
}

///|
pub fn SitemapDocument::diagnostics(
  self : SitemapDocument,
) -> Array[Diagnostic] {
  self.diagnostics
}

///|
pub fn SitemapDocument::entry_count(self : SitemapDocument) -> Int {
  self.entries.length()
}

///|
pub fn SitemapDocument::child_count(self : SitemapDocument) -> Int {
  self.child_sitemaps.length()
}

///|
pub fn SitemapDocument::source_items(self : SitemapDocument) -> Int {
  self.source_items
}

///|
pub fn SitemapDocument::is_valid(self : SitemapDocument) -> Bool {
  diagnostics_at_least(self.diagnostics, Error).length() == 0
}

///|
fn sitemap_diag(
  severity : Severity,
  code : String,
  message : String,
  ordinal : Int,
  hint : String,
) -> Diagnostic {
  make_diagnostic(severity, code, message, ordinal, hint)
}

///|
fn decode_xml_text(value : String) -> String {
  value
  .replace_all(old="&amp;", new="&")
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .trim()
  .to_owned()
}

///|
fn extract_tag(block : String, tag : String) -> String {
  let open = "<\{tag}>"
  let close = "</\{tag}>"
  match block.split_once(open) {
    None => ""
    Some(after_open) =>
      match after_open.1.split_once(close) {
        None => ""
        Some(value) => decode_xml_text(value.0.to_owned())
      }
  }
}

///|
fn extract_blocks(input : String, tag : String) -> Array[String] {
  let output : Array[String] = []
  let open = "<\{tag}>"
  let close = "</\{tag}>"
  let segments = input.split(open).to_array()
  for index = 1; index < segments.length(); index = index + 1 {
    match segments[index].split_once(close) {
      Some(parts) => output.push(parts.0.to_owned())
      None => ()
    }
  }
  output
}

///|
fn valid_change_frequency(value : String) -> Bool {
  value.length() == 0 ||
  value == "always" ||
  value == "hourly" ||
  value == "daily" ||
  value == "weekly" ||
  value == "monthly" ||
  value == "yearly" ||
  value == "never"
}

///|
fn parse_priority_millis(value : String) -> Int {
  if value.length() == 0 {
    return -1
  }
  match value.split_once(".") {
    None => {
      let whole = parse_positive_decimal(value)
      if whole == 0 {
        0
      } else if whole == 1 {
        1000
      } else {
        -2
      }
    }
    Some(parts) => {
      let whole = parse_positive_decimal(parts.0.to_owned())
      let fraction = parts.1.to_owned()
      if (whole != 0 && whole != 1) ||
        fraction.length() == 0 ||
        fraction.length() > 3 {
        return -2
      }
      let parsed_fraction = parse_positive_decimal(fraction)
      if parsed_fraction < 0 {
        return -2
      }
      let scaled = if fraction.length() == 1 {
        parsed_fraction * 100
      } else if fraction.length() == 2 {
        parsed_fraction * 10
      } else {
        parsed_fraction
      }
      if whole == 1 && scaled > 0 {
        -2
      } else {
        whole * 1000 + scaled
      }
    }
  }
}

///|
fn valid_date_prefix(value : String) -> Bool {
  if value.length() < 10 {
    return false
  }
  let chars = value.to_array()
  for index = 0; index < 10; index = index + 1 {
    if index == 4 || index == 7 {
      if chars[index] != '-' {
        return false
      }
    } else if !is_ascii_digit(chars[index]) {
      return false
    }
  }
  true
}

///|
fn add_sitemap_entry(
  block : String,
  ordinal : Int,
  entries : Array[SitemapEntry],
  diagnostics : Array[Diagnostic],
) -> Unit {
  let location = extract_tag(block, "loc")
  let last_modified = extract_tag(block, "lastmod")
  let change_frequency = lower_ascii(extract_tag(block, "changefreq"))
  let priority_text = extract_tag(block, "priority")
  let priority_millis = parse_priority_millis(priority_text)
  if location.length() == 0 {
    diagnostics.push(
      sitemap_diag(
        Error,
        "SMP001",
        "sitemap URL entry has no loc value",
        ordinal,
        "Add one absolute URL in a loc element.",
      ),
    )
    return
  }
  if !parse_url(location).valid {
    diagnostics.push(
      sitemap_diag(
        Error,
        "SMP002",
        "sitemap loc is not a valid absolute HTTP or HTTPS URL",
        ordinal,
        "Use a fully qualified URL.",
      ),
    )
  }
  if array_contains_entry(entries, location) {
    diagnostics.push(
      sitemap_diag(
        Warning,
        "SMP003",
        "duplicate sitemap URL",
        ordinal,
        "Keep one copy of each canonical URL.",
      ),
    )
  }
  if last_modified.length() > 0 && !valid_date_prefix(last_modified) {
    diagnostics.push(
      sitemap_diag(
        Warning,
        "SMP004",
        "lastmod does not start with an ISO date",
        ordinal,
        "Use YYYY-MM-DD or an ISO 8601 timestamp.",
      ),
    )
  }
  if !valid_change_frequency(change_frequency) {
    diagnostics.push(
      sitemap_diag(
        Warning,
        "SMP005",
        "changefreq has an unknown value",
        ordinal,
        "Use a value from the Sitemap protocol vocabulary.",
      ),
    )
  }
  if priority_millis == -2 {
    diagnostics.push(
      sitemap_diag(
        Warning,
        "SMP006",
        "priority is outside the range 0.0 through 1.0",
        ordinal,
        "Use a decimal priority between zero and one.",
      ),
    )
  }
  entries.push({
    location,
    last_modified,
    change_frequency,
    priority_millis: if priority_millis == -2 {
      -1
    } else {
      priority_millis
    },
    ordinal,
  })
}

///|
fn array_contains_entry(
  entries : Array[SitemapEntry],
  location : String,
) -> Bool {
  for entry in entries {
    if canonical_url(entry.location) == canonical_url(location) {
      return true
    }
  }
  false
}

///|
fn parse_urlset(input : String) -> SitemapDocument {
  let entries : Array[SitemapEntry] = []
  let diagnostics : Array[Diagnostic] = []
  let blocks = extract_blocks(input, "url")
  for index, block in blocks {
    add_sitemap_entry(block, index + 1, entries, diagnostics)
  }
  if blocks.length() == 0 {
    diagnostics.push(
      sitemap_diag(
        Warning,
        "SMP007",
        "urlset contains no url elements",
        1,
        "Add URL entries or serve an intentionally empty sitemap.",
      ),
    )
  }
  {
    kind: UrlSet,
    entries,
    child_sitemaps: [],
    diagnostics,
    source_items: blocks.length(),
  }
}

///|
fn parse_sitemap_index(input : String) -> SitemapDocument {
  let children : Array[String] = []
  let diagnostics : Array[Diagnostic] = []
  let blocks = extract_blocks(input, "sitemap")
  for index, block in blocks {
    let location = extract_tag(block, "loc")
    if location.length() == 0 {
      diagnostics.push(
        sitemap_diag(
          Error,
          "SMP008",
          "sitemap index entry has no loc value",
          index + 1,
          "Add an absolute child sitemap URL.",
        ),
      )
    } else {
      if !parse_url(location).valid {
        diagnostics.push(
          sitemap_diag(
            Error,
            "SMP009",
            "child sitemap location is not a valid absolute URL",
            index + 1,
            "Use an absolute HTTP or HTTPS URL.",
          ),
        )
      }
      if !push_unique(children, location) {
        diagnostics.push(
          sitemap_diag(
            Warning,
            "SMP010",
            "duplicate child sitemap location",
            index + 1,
            "Keep one copy of the child location.",
          ),
        )
      }
    }
  }
  {
    kind: SitemapIndex,
    entries: [],
    child_sitemaps: children,
    diagnostics,
    source_items: blocks.length(),
  }
}

///|
fn parse_text_sitemap(input : String) -> SitemapDocument {
  let entries : Array[SitemapEntry] = []
  let diagnostics : Array[Diagnostic] = []
  let lines = input.split("\n").to_array()
  for index, raw in lines {
    let value = strip_carriage_return(raw.to_owned()).trim().to_owned()
    if value.length() == 0 || value.has_prefix("#") {
      continue
    }
    add_sitemap_entry("<loc>\{value}</loc>", index + 1, entries, diagnostics)
  }
  {
    kind: TextSitemap,
    entries,
    child_sitemaps: [],
    diagnostics,
    source_items: entries.length(),
  }
}

///|
/// Parses XML urlsets, XML sitemap indexes, or line-oriented text sitemaps.
pub fn parse_sitemap(input : String) -> SitemapDocument {
  let clean = input.trim().to_owned()
  if clean.contains("<sitemapindex") {
    parse_sitemap_index(clean)
  } else if clean.contains("<urlset") {
    parse_urlset(clean)
  } else if clean.length() > 0 && !clean.has_prefix("<") {
    parse_text_sitemap(clean)
  } else {
    {
      kind: UnknownSitemap,
      entries: [],
      child_sitemaps: [],
      diagnostics: [
        sitemap_diag(
          Error,
          "SMP011",
          "input is not a supported sitemap representation",
          1,
          "Provide a urlset, sitemapindex, or text sitemap.",
        ),
      ],
      source_items: 0,
    }
  }
}

///|
pub fn allowed_sitemap_entries(
  policy : Policy,
  agent : String,
  document : SitemapDocument,
) -> Array[SitemapEntry] {
  let output : Array[SitemapEntry] = []
  for entry in document.entries {
    let path = entry.path()
    if path.length() > 0 && can_fetch(policy, agent, path) {
      output.push(entry)
    }
  }
  output
}

///|
pub fn blocked_sitemap_entries(
  policy : Policy,
  agent : String,
  document : SitemapDocument,
) -> Array[SitemapEntry] {
  let output : Array[SitemapEntry] = []
  for entry in document.entries {
    let path = entry.path()
    if path.length() > 0 && !can_fetch(policy, agent, path) {
      output.push(entry)
    }
  }
  output
}

///|
pub fn cross_origin_entries(
  document : SitemapDocument,
  expected_origin : String,
) -> Array[SitemapEntry] {
  let output : Array[SitemapEntry] = []
  let expected = parse_url(expected_origin)
  if !expected.valid {
    return output
  }
  for entry in document.entries {
    let parsed = parse_url(entry.location)
    if parsed.valid && parsed.origin() != expected.origin() {
      output.push(entry)
    }
  }
  output
}

///|
pub fn render_sitemap_summary(document : SitemapDocument) -> String {
  let output = StringBuilder::new()
  output.write_string("kind: \{document.kind.label()}\n")
  output.write_string("entries: \{document.entries.length()}\n")
  output.write_string("child sitemaps: \{document.child_sitemaps.length()}\n")
  output.write_string("diagnostics: \{document.diagnostics.length()}\n")
  output.to_string()
}

///|
pub fn render_blocked_sitemap_report(
  policy : Policy,
  agent : String,
  document : SitemapDocument,
) -> String {
  let blocked = blocked_sitemap_entries(policy, agent, document)
  let output = StringBuilder::new()
  output.write_string("# Sitemap access conflicts\n\n")
  output.write_string("Agent: `\{agent}`\n\n")
  output.write_string("Blocked entries: \{blocked.length()}\n\n")
  for entry in blocked {
    let decision = decide(policy, agent, entry.path())
    output.write_string("- ")
    output.write_string(entry.location)
    output.write_string(" — ")
    output.write_string(decision.summary())
    output.write_char('\n')
  }
  output.to_string()
}
