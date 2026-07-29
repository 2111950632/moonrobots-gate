///|
/// Parsed HTTP or HTTPS URL used by sitemap and audit helpers.
pub struct ParsedUrl {
  scheme : String
  authority : String
  host : String
  port : Int
  path_query : String
  fragment : String
  valid : Bool
  error : String
} derive(Eq, Debug)

///|
pub fn ParsedUrl::scheme(self : ParsedUrl) -> String {
  self.scheme
}

///|
pub fn ParsedUrl::authority(self : ParsedUrl) -> String {
  self.authority
}

///|
pub fn ParsedUrl::host(self : ParsedUrl) -> String {
  self.host
}

///|
pub fn ParsedUrl::port(self : ParsedUrl) -> Int {
  self.port
}

///|
pub fn ParsedUrl::path_query(self : ParsedUrl) -> String {
  self.path_query
}

///|
pub fn ParsedUrl::fragment(self : ParsedUrl) -> String {
  self.fragment
}

///|
pub fn ParsedUrl::valid(self : ParsedUrl) -> Bool {
  self.valid
}

///|
pub fn ParsedUrl::error(self : ParsedUrl) -> String {
  self.error
}

///|
pub fn ParsedUrl::origin(self : ParsedUrl) -> String {
  if !self.valid {
    return ""
  }
  let default_port = (self.scheme == "http" && self.port == 80) ||
    (self.scheme == "https" && self.port == 443)
  if self.port < 0 || default_port {
    "\{self.scheme}://\{self.host}"
  } else {
    "\{self.scheme}://\{self.host}:\{self.port}"
  }
}

///|
pub fn ParsedUrl::robots_url(self : ParsedUrl) -> String {
  if self.valid {
    "\{self.origin()}/robots.txt"
  } else {
    ""
  }
}

///|
pub fn ParsedUrl::without_fragment(self : ParsedUrl) -> String {
  if !self.valid {
    ""
  } else {
    "\{self.origin()}\{self.path_query}"
  }
}

///|
fn invalid_url(error : String) -> ParsedUrl {
  {
    scheme: "",
    authority: "",
    host: "",
    port: -1,
    path_query: "/",
    fragment: "",
    valid: false,
    error,
  }
}

///|
fn first_delimiter_index(input : String) -> Int {
  let chars = input.to_array()
  for index, char in chars {
    if char == '/' || char == '?' || char == '#' {
      return index
    }
  }
  chars.length()
}

///|
fn split_fragment(input : String) -> (String, String) {
  match input.split_once("#") {
    Some(parts) => (parts.0.to_owned(), parts.1.to_owned())
    None => (input, "")
  }
}

///|
fn split_host_port(
  authority : String,
  scheme : String,
) -> (String, Int, String) {
  if authority.length() == 0 {
    return ("", -1, "authority is empty")
  }
  if authority.contains("@") {
    return ("", -1, "userinfo is not accepted in audit URLs")
  }
  if authority.has_prefix("[") {
    match authority.split_once("]") {
      None => ("", -1, "IPv6 host is missing a closing bracket")
      Some(parts) => {
        let host = "[\{lower_ascii(string_from(parts.0.to_owned(), 1))}]"
        let suffix = parts.1.to_owned()
        if suffix.length() == 0 {
          let default_port = if scheme == "https" { 443 } else { 80 }
          (host, default_port, "")
        } else if suffix.has_prefix(":") {
          let port = parse_positive_decimal(string_from(suffix, 1))
          if port < 1 || port > 65535 {
            ("", -1, "port is outside 1..65535")
          } else {
            (host, port, "")
          }
        } else {
          ("", -1, "unexpected text after IPv6 host")
        }
      }
    }
  } else {
    match authority.rev_split_once(":") {
      Some(parts) => {
        let host = lower_ascii(parts.0.to_owned())
        let port_text = parts.1.to_owned()
        if port_text.length() > 0 {
          let port = parse_positive_decimal(port_text)
          if port < 1 || port > 65535 {
            ("", -1, "port is outside 1..65535")
          } else {
            (host, port, "")
          }
        } else {
          ("", -1, "port is empty")
        }
      }
      None => {
        let default_port = if scheme == "https" { 443 } else { 80 }
        (lower_ascii(authority), default_port, "")
      }
    }
  }
}

///|
fn valid_host(host : String) -> Bool {
  if host.length() == 0 {
    return false
  }
  if host.has_prefix("[") && host.has_suffix("]") {
    return true
  }
  let mut label_length = 0
  for char in host {
    if char == '.' {
      if label_length == 0 {
        return false
      }
      label_length = 0
    } else if is_ascii_letter(char) ||
      is_ascii_digit(char) ||
      char == '-' ||
      char == '_' {
      label_length = label_length + 1
    } else {
      return false
    }
  }
  label_length > 0
}

///|
/// Parses an absolute HTTP or HTTPS URL without network access.
pub fn parse_url(input : String) -> ParsedUrl {
  let clean = input.trim().to_owned()
  let lower = lower_ascii(clean)
  let scheme = if lower.has_prefix("https://") {
    "https"
  } else if lower.has_prefix("http://") {
    "http"
  } else {
    return invalid_url("only absolute HTTP and HTTPS URLs are supported")
  }
  let prefix_length = if scheme == "https" { 8 } else { 7 }
  let remainder = string_from(clean, prefix_length)
  let authority_end = first_delimiter_index(remainder)
  let authority = string_slice(remainder, 0, authority_end)
  let tail = string_from(remainder, authority_end)
  let (without_fragment, fragment) = split_fragment(tail)
  let path_query = if without_fragment.length() == 0 {
    "/"
  } else if without_fragment.has_prefix("?") {
    "/\{without_fragment}"
  } else {
    without_fragment
  }
  let (host, port, error) = split_host_port(authority, scheme)
  if error.length() > 0 {
    return invalid_url(error)
  }
  if !valid_host(host) {
    return invalid_url("host contains invalid characters or empty labels")
  }
  {
    scheme,
    authority,
    host,
    port,
    path_query: normalize_path(path_query),
    fragment,
    valid: true,
    error: "",
  }
}

///|
pub fn same_origin(left : String, right : String) -> Bool {
  let a = parse_url(left)
  let b = parse_url(right)
  a.valid && b.valid && a.origin() == b.origin()
}

///|
pub fn url_path(input : String) -> String {
  let parsed = parse_url(input)
  if parsed.valid {
    parsed.path_query
  } else {
    ""
  }
}

///|
pub fn robots_url_for(input : String) -> String {
  parse_url(input).robots_url()
}

///|
pub fn remove_url_fragment(input : String) -> String {
  parse_url(input).without_fragment()
}

///|
pub fn url_has_query(input : String) -> Bool {
  let parsed = parse_url(input)
  parsed.valid && parsed.path_query.contains("?")
}

///|
pub fn url_depth(input : String) -> Int {
  let parsed = parse_url(input)
  if !parsed.valid {
    return -1
  }
  let path = match parsed.path_query.split_once("?") {
    Some(parts) => parts.0.to_owned()
    None => parsed.path_query
  }
  let mut depth = 0
  for segment in path.split("/") {
    if segment.length() > 0 {
      depth = depth + 1
    }
  }
  depth
}

///|
pub fn canonical_url(input : String) -> String {
  let parsed = parse_url(input)
  if !parsed.valid {
    return ""
  }
  let path_query = if parsed.path_query.length() == 0 {
    "/"
  } else {
    parsed.path_query
  }
  "\{parsed.origin()}\{path_query}"
}
