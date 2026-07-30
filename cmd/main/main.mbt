///|
fn usage() -> String {
  (
    #|MoonRobots Gate
    #|
    #|Usage:
    #|  moon run cmd/main -- decide <user-agent> <path>
    #|  moon run cmd/main -- lint [strict]
    #|  moon run cmd/main -- normalize
    #|  moon run cmd/main -- matrix
    #|  moon run cmd/main -- sitemap
    #|  moon run cmd/main -- plan
    #|  moon run cmd/main -- diff
    #|  moon run cmd/main -- audit [json]
    #|  moon run cmd/main -- stats
    #|
    #|Input:
    #|  MOONROBOTS_POLICY   Optional robots.txt text.
    #|  MOONROBOTS_SITEMAP Optional XML or text sitemap.
  )
}

///|
fn sample_policy() -> String {
  (
    #|User-agent: *
    #|Disallow: /private/
    #|Disallow: /admin/
    #|Allow: /private/public/
    #|Crawl-delay: 1.5
    #|
    #|User-agent: ResearchBot
    #|Disallow: /tmp/*.json$
    #|Allow: /tmp/public/
    #|
    #|Sitemap: https://example.com/sitemap.xml
  )
}

///|
fn sample_sitemap() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #|  <url>
    #|    <loc>https://example.com/</loc>
    #|    <lastmod>2026-07-29</lastmod>
    #|    <priority>1.0</priority>
    #|  </url>
    #|  <url>
    #|    <loc>https://example.com/docs/guide</loc>
    #|    <priority>0.8</priority>
    #|  </url>
    #|  <url>
    #|    <loc>https://example.com/private/report</loc>
    #|    <priority>0.2</priority>
    #|  </url>
    #|</urlset>
  )
}

///|
fn policy_input() -> String {
  match @env.get_env_var("MOONROBOTS_POLICY") {
    Some(value) => value
    None => sample_policy()
  }
}

///|
fn sitemap_input() -> String {
  match @env.get_env_var("MOONROBOTS_SITEMAP") {
    Some(value) => value
    None => sample_sitemap()
  }
}

///|
fn command_decide(args : Array[String], policy : @gate.Policy) -> Unit {
  if args.length() < 4 {
    println("decide requires <user-agent> and <path>")
    return
  }
  let decision = @gate.decide(policy, args[2], args[3])
  println(@gate.render_decision_trace(decision))
}

///|
fn command_lint(args : Array[String], policy : @gate.Policy) -> Unit {
  let options = if args.length() >= 3 && args[2] == "strict" {
    @gate.strict_lint_options()
  } else {
    @gate.default_lint_options()
  }
  let diagnostics = @gate.all_diagnostics_with_options(policy, options)
  println(@gate.render_policy_summary(policy))
  if diagnostics.length() == 0 {
    println("No diagnostics.")
  } else {
    println(@gate.render_diagnostics(diagnostics))
  }
}

///|
fn command_normalize(policy : @gate.Policy) -> Unit {
  println(@gate.render_policy(policy, @gate.Canonical))
}

///|
fn command_matrix(policy : @gate.Policy) -> Unit {
  let probes = @gate.build_probe_grid(
    ["GenericBot", "ResearchBot/2.0", "GPTBot"],
    ["/", "/docs/", "/admin/", "/private/report", "/private/public/readme"],
  )
  println(@gate.render_matrix_markdown(@gate.run_matrix(policy, probes)))
}

///|
fn command_sitemap(policy : @gate.Policy) -> Unit {
  let sitemap = @gate.parse_sitemap(sitemap_input())
  println(@gate.render_sitemap_summary(sitemap))
  println(@gate.render_blocked_sitemap_report(policy, "GenericBot", sitemap))
}

///|
fn command_plan(policy : @gate.Policy) -> Unit {
  let sitemap = @gate.parse_sitemap(sitemap_input())
  let tasks = @gate.tasks_from_sitemap(sitemap, 32768)
  let budget = @gate.crawl_budget(20, 1000000, 6, 10, 1000)
  let plan = @gate.plan_crawl(policy, "GenericBot", tasks, budget)
  println(@gate.render_crawl_plan(plan))
}

///|
fn command_diff(policy : @gate.Policy) -> Unit {
  let baseline = @gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
      #|Allow: /private/public/
      #|Sitemap: https://example.com/old-sitemap.xml
    ),
  )
  let probes = @gate.build_probe_grid(["GenericBot", "ResearchBot"], [
    "/", "/admin/", "/private/report", "/private/public/readme",
  ])
  println(@gate.render_diff(@gate.diff_policies(baseline, policy, probes)))
}

///|
fn command_audit(args : Array[String]) -> Unit {
  let result = @gate.audit_default(policy_input())
  if args.length() >= 3 && args[2] == "json" {
    println(@gate.render_audit_json(result))
  } else {
    println(@gate.render_audit_markdown(result))
  }
}

///|
fn command_stats(policy : @gate.Policy) -> Unit {
  println(@gate.render_policy_summary(policy))
  println(
    "canonical characters: \{@gate.render_policy(policy, @gate.Canonical).length()}",
  )
  println("valid: \{policy.is_valid()}")
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 || args[1] == "--help" || args[1] == "-h" {
    println(usage())
    return
  }
  let policy = @gate.parse(policy_input())
  match args[1] {
    "decide" => command_decide(args, policy)
    "lint" => command_lint(args, policy)
    "normalize" => command_normalize(policy)
    "matrix" => command_matrix(policy)
    "sitemap" => command_sitemap(policy)
    "plan" => command_plan(policy)
    "diff" => command_diff(policy)
    "audit" => command_audit(args)
    "stats" => command_stats(policy)
    command => {
      println("Unknown command: \{command}")
      println(usage())
    }
  }
}
