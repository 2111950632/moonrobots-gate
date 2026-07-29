///|
fn lower_ascii(input : String) -> String {
  let output : Array[Char] = []
  for char in input {
    let code = char.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      output.push((code + 32).unsafe_to_char())
    } else {
      output.push(char)
    }
  }
  String::from_array(output)
}

///|
fn strip_comment(line : String) -> String {
  match line.split_once("#") {
    Some(parts) => parts.0.to_owned()
    None => line
  }
}

///|
fn strip_carriage_return(line : String) -> String {
  if line.has_suffix("\r") {
    let chars = line.to_array()
    String::from_array(chars[0:chars.length() - 1])
  } else {
    line
  }
}

///|
fn strip_utf8_bom(line : String) -> String {
  let chars = line.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    String::from_array(chars[1:])
  } else {
    line
  }
}

///|
fn string_slice(input : String, start : Int, end : Int) -> String {
  String::from_array(input.to_array()[start:end])
}

///|
fn string_from(input : String, start : Int) -> String {
  String::from_array(input.to_array()[start:])
}

///|
fn directive_kind(key : String) -> DirectiveKind {
  match lower_ascii(key) {
    "user-agent" => UserAgentDirective
    "allow" => AllowDirective
    "disallow" => DisallowDirective
    "sitemap" => SitemapDirective
    "crawl-delay" => CrawlDelayDirective
    "host" => HostDirective
    "clean-param" => CleanParamDirective
    _ => UnknownDirective
  }
}

///|
fn is_ascii_letter(char : Char) -> Bool {
  let code = char.to_int()
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int())
}

///|
fn is_ascii_digit(char : Char) -> Bool {
  let code = char.to_int()
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn is_agent_char(char : Char) -> Bool {
  is_ascii_letter(char) ||
  is_ascii_digit(char) ||
  char == '-' ||
  char == '_' ||
  char == '.'
}

///|
fn valid_agent_token(agent : String) -> Bool {
  if agent == "*" {
    return true
  }
  if agent.length() == 0 {
    return false
  }
  for char in agent {
    if !is_agent_char(char) {
      return false
    }
  }
  true
}

///|
fn is_control_char(char : Char) -> Bool {
  let code = char.to_int()
  (code >= 0 && code < 32 && char != '\t') || code == 127
}

///|
fn contains_control_char(input : String) -> Bool {
  for char in input {
    if is_control_char(char) {
      return true
    }
  }
  false
}

///|
fn parse_positive_decimal(input : String) -> Int {
  if input.length() == 0 {
    return -1
  }
  let mut value = 0
  for char in input {
    if !is_ascii_digit(char) {
      return -1
    }
    value = value * 10 + char.to_int() - '0'.to_int()
    if value > 100000000 {
      return -1
    }
  }
  value
}

///|
fn parse_delay_millis(input : String) -> Int {
  let clean = input.trim().to_owned()
  match clean.split_once(".") {
    None => {
      let seconds = parse_positive_decimal(clean)
      if seconds < 0 {
        -1
      } else {
        seconds * 1000
      }
    }
    Some(parts) => {
      let seconds = parse_positive_decimal(parts.0.to_owned())
      let fraction = parts.1.to_owned()
      if seconds < 0 || fraction.length() == 0 || fraction.length() > 3 {
        return -1
      }
      let fraction_value = parse_positive_decimal(fraction)
      if fraction_value < 0 {
        return -1
      }
      let multiplier = if fraction.length() == 1 {
        100
      } else if fraction.length() == 2 {
        10
      } else {
        1
      }
      seconds * 1000 + fraction_value * multiplier
    }
  }
}

///|
fn hex_value(char : Char) -> Int {
  let code = char.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    code - 'A'.to_int() + 10
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else {
    -1
  }
}

///|
fn upper_hex_char(char : Char) -> Char {
  let code = char.to_int()
  if code >= 'a'.to_int() && code <= 'f'.to_int() {
    (code - 32).unsafe_to_char()
  } else {
    char
  }
}

///|
fn is_unreserved_ascii(code : Int) -> Bool {
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  code == '-'.to_int() ||
  code == '.'.to_int() ||
  code == '_'.to_int() ||
  code == '~'.to_int()
}

///|
/// Decodes percent-encoded unreserved ASCII while preserving reserved octets.
pub fn normalize_percent_encoding(input : String) -> String {
  let chars = input.to_array()
  let output : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '%' && index + 2 < chars.length() {
      let high = hex_value(chars[index + 1])
      let low = hex_value(chars[index + 2])
      if high >= 0 && low >= 0 {
        let code = high * 16 + low
        if is_unreserved_ascii(code) {
          output.push(code.unsafe_to_char())
        } else {
          output.push('%')
          output.push(upper_hex_char(chars[index + 1]))
          output.push(upper_hex_char(chars[index + 2]))
        }
        index = index + 3
        continue
      }
    }
    output.push(chars[index])
    index = index + 1
  }
  String::from_array(output)
}

///|
fn normalize_rule_pattern(pattern : String) -> String {
  normalize_percent_encoding(pattern)
}

///|
/// Normalizes a URL path for RFC 9309 comparison.
pub fn normalize_path(path : String) -> String {
  let clean = if path.length() == 0 {
    "/"
  } else if path.has_prefix("/") {
    path
  } else {
    "/\{path}"
  }
  normalize_percent_encoding(clean)
}

///|
fn rule_specificity(pattern : String) -> Int {
  let chars = pattern.to_array()
  let mut count = 0
  for char in chars {
    if char != '*' && char != '$' {
      count = count + 1
    }
  }
  count
}

///|
fn count_char(input : String, target : Char) -> Int {
  let mut count = 0
  for char in input {
    if char == target {
      count = count + 1
    }
  }
  count
}

///|
fn array_contains_string(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}

///|
fn push_unique(items : Array[String], value : String) -> Bool {
  if array_contains_string(items, value) {
    false
  } else {
    items.push(value)
    true
  }
}

///|
fn join_strings(items : Array[String], separator : String) -> String {
  let buffer = StringBuilder::new()
  for index, item in items {
    if index > 0 {
      buffer.write_string(separator)
    }
    buffer.write_string(item)
  }
  buffer.to_string()
}

///|
fn is_absolute_http_url(value : String) -> Bool {
  let lower = lower_ascii(value)
  (lower.has_prefix("http://") && value.length() > 7) ||
  (lower.has_prefix("https://") && value.length() > 8)
}

///|
