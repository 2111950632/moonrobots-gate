///|
/// Candidate URL submitted to the deterministic crawl planner.
pub struct CrawlTask {
  id : String
  url : String
  priority : Int
  depth : Int
  estimated_bytes : Int
  discovered_from : String
} derive(Eq, Debug)

///|
pub fn crawl_task(
  id : String,
  url : String,
  priority : Int,
  depth : Int,
  estimated_bytes : Int,
) -> CrawlTask {
  { id, url, priority, depth, estimated_bytes, discovered_from: "" }
}

///|
pub fn discovered_crawl_task(
  id : String,
  url : String,
  priority : Int,
  depth : Int,
  estimated_bytes : Int,
  discovered_from : String,
) -> CrawlTask {
  { id, url, priority, depth, estimated_bytes, discovered_from }
}

///|
pub fn CrawlTask::id(self : CrawlTask) -> String {
  self.id
}

///|
pub fn CrawlTask::url(self : CrawlTask) -> String {
  self.url
}

///|
pub fn CrawlTask::priority(self : CrawlTask) -> Int {
  self.priority
}

///|
pub fn CrawlTask::depth(self : CrawlTask) -> Int {
  self.depth
}

///|
pub fn CrawlTask::estimated_bytes(self : CrawlTask) -> Int {
  self.estimated_bytes
}

///|
pub fn CrawlTask::discovered_from(self : CrawlTask) -> String {
  self.discovered_from
}

///|
/// Resource and safety limits for a crawl planning run.
pub struct CrawlBudget {
  max_requests : Int
  max_bytes : Int
  max_depth : Int
  max_requests_per_host : Int
  fallback_delay_millis : Int
} derive(Eq, Debug)

///|
pub fn crawl_budget(
  max_requests : Int,
  max_bytes : Int,
  max_depth : Int,
  max_requests_per_host : Int,
  fallback_delay_millis : Int,
) -> CrawlBudget {
  {
    max_requests,
    max_bytes,
    max_depth,
    max_requests_per_host,
    fallback_delay_millis,
  }
}

///|
pub fn default_crawl_budget() -> CrawlBudget {
  {
    max_requests: 100,
    max_bytes: 100000000,
    max_depth: 8,
    max_requests_per_host: 50,
    fallback_delay_millis: 1000,
  }
}

///|
pub fn CrawlBudget::max_requests(self : CrawlBudget) -> Int {
  self.max_requests
}

///|
pub fn CrawlBudget::max_bytes(self : CrawlBudget) -> Int {
  self.max_bytes
}

///|
pub fn CrawlBudget::max_depth(self : CrawlBudget) -> Int {
  self.max_depth
}

///|
pub fn CrawlBudget::max_requests_per_host(self : CrawlBudget) -> Int {
  self.max_requests_per_host
}

///|
pub fn CrawlBudget::fallback_delay_millis(self : CrawlBudget) -> Int {
  self.fallback_delay_millis
}

///|
/// Why a task was rejected by the planner.
pub(all) enum RejectionReason {
  InvalidUrl
  RobotsDenied
  DepthExceeded
  RequestBudgetExceeded
  ByteBudgetExceeded
  HostBudgetExceeded
  DuplicateUrl
} derive(Eq, Debug)

///|
pub fn RejectionReason::label(self : RejectionReason) -> String {
  match self {
    InvalidUrl => "invalid-url"
    RobotsDenied => "robots-denied"
    DepthExceeded => "depth-exceeded"
    RequestBudgetExceeded => "request-budget-exceeded"
    ByteBudgetExceeded => "byte-budget-exceeded"
    HostBudgetExceeded => "host-budget-exceeded"
    DuplicateUrl => "duplicate-url"
  }
}

///|
/// A task accepted into the crawl plan.
pub struct PlannedTask {
  task : CrawlTask
  canonical_url : String
  host : String
  path : String
  sequence : Int
  not_before_millis : Int
  decision : Decision
} derive(Eq, Debug)

///|
pub fn PlannedTask::task(self : PlannedTask) -> CrawlTask {
  self.task
}

///|
pub fn PlannedTask::canonical_url(self : PlannedTask) -> String {
  self.canonical_url
}

///|
pub fn PlannedTask::host(self : PlannedTask) -> String {
  self.host
}

///|
pub fn PlannedTask::path(self : PlannedTask) -> String {
  self.path
}

///|
pub fn PlannedTask::sequence(self : PlannedTask) -> Int {
  self.sequence
}

///|
pub fn PlannedTask::not_before_millis(self : PlannedTask) -> Int {
  self.not_before_millis
}

///|
pub fn PlannedTask::decision(self : PlannedTask) -> Decision {
  self.decision
}

///|
/// A task rejected by one deterministic planning constraint.
pub struct RejectedTask {
  task : CrawlTask
  reason : RejectionReason
  detail : String
} derive(Eq, Debug)

///|
pub fn RejectedTask::task(self : RejectedTask) -> CrawlTask {
  self.task
}

///|
pub fn RejectedTask::reason(self : RejectedTask) -> RejectionReason {
  self.reason
}

///|
pub fn RejectedTask::detail(self : RejectedTask) -> String {
  self.detail
}

///|
/// Output of a deterministic, policy-aware crawl planning pass.
pub struct CrawlPlan {
  accepted : Array[PlannedTask]
  rejected : Array[RejectedTask]
  total_estimated_bytes : Int
  estimated_duration_millis : Int
} derive(Eq, Debug)

///|
pub fn CrawlPlan::accepted(self : CrawlPlan) -> Array[PlannedTask] {
  self.accepted
}

///|
pub fn CrawlPlan::rejected(self : CrawlPlan) -> Array[RejectedTask] {
  self.rejected
}

///|
pub fn CrawlPlan::accepted_count(self : CrawlPlan) -> Int {
  self.accepted.length()
}

///|
pub fn CrawlPlan::rejected_count(self : CrawlPlan) -> Int {
  self.rejected.length()
}

///|
pub fn CrawlPlan::total_estimated_bytes(self : CrawlPlan) -> Int {
  self.total_estimated_bytes
}

///|
pub fn CrawlPlan::estimated_duration_millis(self : CrawlPlan) -> Int {
  self.estimated_duration_millis
}

///|
fn int_array_contains(items : Array[Int], value : Int) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn accepted_contains_url(items : Array[PlannedTask], url : String) -> Bool {
  for item in items {
    if item.canonical_url == url {
      return true
    }
  }
  false
}

///|
fn accepted_host_count(items : Array[PlannedTask], host : String) -> Int {
  let mut count = 0
  for item in items {
    if item.host == host {
      count = count + 1
    }
  }
  count
}

///|
fn highest_unselected(tasks : Array[CrawlTask], selected : Array[Int]) -> Int {
  let mut best = -1
  let mut best_priority = -2147483647
  for index, task in tasks {
    if !int_array_contains(selected, index) {
      if best < 0 ||
        task.priority > best_priority ||
        (task.priority == best_priority && index < best) {
        best = index
        best_priority = task.priority
      }
    }
  }
  best
}

///|
fn reject_task(
  output : Array[RejectedTask],
  task : CrawlTask,
  reason : RejectionReason,
  detail : String,
) -> Unit {
  output.push({ task, reason, detail })
}

///|
fn safe_estimated_bytes(task : CrawlTask) -> Int {
  if task.estimated_bytes < 0 {
    0
  } else {
    task.estimated_bytes
  }
}

///|
/// Plans crawl order by priority while enforcing protocol and budget limits.
pub fn plan_crawl(
  policy : Policy,
  agent : String,
  tasks : Array[CrawlTask],
  budget : CrawlBudget,
) -> CrawlPlan {
  let accepted : Array[PlannedTask] = []
  let rejected : Array[RejectedTask] = []
  let selected : Array[Int] = []
  let policy_delay = crawl_delay(policy, agent)
  let delay = if policy_delay >= 0 {
    policy_delay
  } else {
    budget.fallback_delay_millis
  }
  let mut total_estimated_bytes = 0
  let mut estimated_duration_millis = 0
  while selected.length() < tasks.length() {
    let index = highest_unselected(tasks, selected)
    if index < 0 {
      break
    }
    selected.push(index)
    let task = tasks[index]
    let parsed = parse_url(task.url)
    if !parsed.valid {
      reject_task(rejected, task, InvalidUrl, parsed.error)
      continue
    }
    let canonical = parsed.without_fragment()
    if accepted_contains_url(accepted, canonical) {
      reject_task(
        rejected,
        task,
        DuplicateUrl,
        "canonical URL already exists in the accepted plan",
      )
      continue
    }
    if task.depth > budget.max_depth {
      reject_task(
        rejected,
        task,
        DepthExceeded,
        "task depth \{task.depth} exceeds \{budget.max_depth}",
      )
      continue
    }
    let decision = decide(policy, agent, parsed.path_query)
    if !decision.allowed {
      reject_task(rejected, task, RobotsDenied, decision.summary())
      continue
    }
    if accepted.length() >= budget.max_requests {
      reject_task(
        rejected,
        task,
        RequestBudgetExceeded,
        "accepted request limit reached",
      )
      continue
    }
    let host_count = accepted_host_count(accepted, parsed.host)
    if host_count >= budget.max_requests_per_host {
      reject_task(
        rejected,
        task,
        HostBudgetExceeded,
        "per-host request limit reached for \{parsed.host}",
      )
      continue
    }
    let bytes = safe_estimated_bytes(task)
    if total_estimated_bytes + bytes > budget.max_bytes {
      reject_task(
        rejected,
        task,
        ByteBudgetExceeded,
        "estimated byte budget would be exceeded",
      )
      continue
    }
    let not_before_millis = host_count * delay
    accepted.push({
      task,
      canonical_url: canonical,
      host: parsed.host,
      path: parsed.path_query,
      sequence: accepted.length() + 1,
      not_before_millis,
      decision,
    })
    total_estimated_bytes = total_estimated_bytes + bytes
    if not_before_millis > estimated_duration_millis {
      estimated_duration_millis = not_before_millis
    }
  }
  { accepted, rejected, total_estimated_bytes, estimated_duration_millis }
}

///|
pub fn rejected_for_reason(
  plan : CrawlPlan,
  reason : RejectionReason,
) -> Array[RejectedTask] {
  let output : Array[RejectedTask] = []
  for item in plan.rejected {
    if item.reason == reason {
      output.push(item)
    }
  }
  output
}

///|
pub fn render_crawl_plan(plan : CrawlPlan) -> String {
  let output = StringBuilder::new()
  output.write_string("# Crawl plan\n\n")
  output.write_string("Accepted: \{plan.accepted.length()}\n\n")
  output.write_string("Rejected: \{plan.rejected.length()}\n\n")
  output.write_string("Estimated bytes: \{plan.total_estimated_bytes}\n\n")
  output.write_string("| # | ID | URL | Not before (ms) |\n")
  output.write_string("|---:|---|---|---:|\n")
  for item in plan.accepted {
    output.write_string(
      "| \{item.sequence} | \{item.task.id} | \{item.canonical_url} | \{item.not_before_millis} |\n",
    )
  }
  if plan.rejected.length() > 0 {
    output.write_string("\n## Rejected\n\n")
    for item in plan.rejected {
      output.write_string(
        "- `\{item.task.id}` \{item.reason.label()}: \{item.detail}\n",
      )
    }
  }
  output.to_string()
}

///|
pub fn tasks_from_sitemap(
  document : SitemapDocument,
  default_bytes : Int,
) -> Array[CrawlTask] {
  let output : Array[CrawlTask] = []
  for entry in document.entries {
    let priority = if entry.priority_millis >= 0 {
      entry.priority_millis
    } else {
      500
    }
    output.push({
      id: "sitemap-\{entry.ordinal}",
      url: entry.location,
      priority,
      depth: url_depth(entry.location),
      estimated_bytes: default_bytes,
      discovered_from: "sitemap",
    })
  }
  output
}
