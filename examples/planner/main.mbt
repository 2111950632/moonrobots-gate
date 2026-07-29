///|
fn main {
  let policy = @gate.parse(
    (
      #|User-agent: *
      #|Disallow: /private/
      #|Crawl-delay: 2
    ),
  )
  let tasks = [
    @gate.crawl_task("home", "https://example.com/", 100, 0, 8192),
    @gate.crawl_task("docs", "https://example.com/docs", 80, 1, 16384),
    @gate.crawl_task(
      "private", "https://example.com/private/report", 90, 1, 32768,
    ),
    @gate.crawl_task("deep", "https://example.com/a/b/c/d", 10, 4, 4096),
  ]
  let budget = @gate.crawl_budget(10, 100000, 3, 5, 1000)
  println(
    @gate.render_crawl_plan(@gate.plan_crawl(policy, "DemoBot", tasks, budget)),
  )
}
