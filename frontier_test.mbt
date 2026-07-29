///|
fn open_policy() -> @robots-gate.Policy {
  @robots-gate.parse(
    (
      #|User-agent: *
      #|Allow: /
      #|Disallow: /private
      #|Crawl-delay: 2
    ),
  )
}

///|
test "crawl planner sorts by priority" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("low", "https://example.com/low", 1, 1, 10),
      @robots-gate.crawl_task("high", "https://example.com/high", 9, 1, 10),
    ],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.accepted()[0].task().id(), content="high")
}

///|
test "crawl planner rejects robots denied tasks" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task(
        "private", "https://example.com/private/report", 1, 1, 10,
      ),
    ],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.accepted_count(), content="0")
  inspect(plan.rejected()[0].reason().label(), content="robots-denied")
}

///|
test "crawl planner rejects invalid URLs" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [@robots-gate.crawl_task("bad", "/relative", 1, 1, 10)],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.rejected()[0].reason().label(), content="invalid-url")
}

///|
test "crawl planner applies depth limits" {
  let budget = @robots-gate.crawl_budget(10, 1000, 2, 10, 0)
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [@robots-gate.crawl_task("deep", "https://example.com/a/b/c", 1, 3, 10)],
    budget,
  )
  inspect(plan.rejected()[0].reason().label(), content="depth-exceeded")
}

///|
test "crawl planner applies request limits" {
  let budget = @robots-gate.crawl_budget(1, 1000, 5, 10, 0)
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://example.com/a", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://example.com/b", 1, 1, 10),
    ],
    budget,
  )
  inspect(plan.accepted_count(), content="1")
  inspect(
    @robots-gate.rejected_for_reason(plan, @robots-gate.RequestBudgetExceeded).length(),
    content="1",
  )
}

///|
test "crawl planner applies byte limits" {
  let budget = @robots-gate.crawl_budget(10, 15, 5, 10, 0)
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://example.com/a", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://example.com/b", 1, 1, 10),
    ],
    budget,
  )
  inspect(plan.total_estimated_bytes(), content="10")
  inspect(plan.rejected()[0].reason().label(), content="byte-budget-exceeded")
}

///|
test "crawl planner applies per-host limits" {
  let budget = @robots-gate.crawl_budget(10, 1000, 5, 1, 0)
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://example.com/a", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://example.com/b", 1, 1, 10),
    ],
    budget,
  )
  inspect(plan.rejected()[0].reason().label(), content="host-budget-exceeded")
}

///|
test "crawl planner deduplicates fragment variants" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://example.com/a#one", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://example.com/a#two", 1, 1, 10),
    ],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.accepted_count(), content="1")
  inspect(plan.rejected()[0].reason().label(), content="duplicate-url")
}

///|
test "crawl planner schedules host delay" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://example.com/a", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://example.com/b", 1, 1, 10),
    ],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.accepted()[0].not_before_millis(), content="0")
  inspect(plan.accepted()[1].not_before_millis(), content="2000")
  inspect(plan.estimated_duration_millis(), content="2000")
}

///|
test "crawl planner schedules hosts independently" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("a", "https://a.example/a", 2, 1, 10),
      @robots-gate.crawl_task("b", "https://b.example/b", 1, 1, 10),
    ],
    @robots-gate.default_crawl_budget(),
  )
  inspect(plan.accepted()[1].not_before_millis(), content="0")
}

///|
test "crawl plan renders accepted and rejected tasks" {
  let plan = @robots-gate.plan_crawl(
    open_policy(),
    "bot",
    [
      @robots-gate.crawl_task("ok", "https://example.com/", 2, 0, 10),
      @robots-gate.crawl_task("no", "https://example.com/private", 1, 1, 10),
    ],
    @robots-gate.default_crawl_budget(),
  )
  let report = @robots-gate.render_crawl_plan(plan)
  inspect(report.contains("# Crawl plan"), content="true")
  inspect(report.contains("robots-denied"), content="true")
}
