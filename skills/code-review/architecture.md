---
name: code-review
description: Analyze Java project architecture at macro level - package structure, module boundaries, dependency direction, and layering. Use when user asks "review architecture", "check structure", "package organization", or when evaluating if a codebase follows clean architecture principles.
---

# Architecture Review Skill

Analyze package/module structure and layering **against what the target repo actually does today**,
not a generic template. This applies to any Java/Spring Boot (or Jakarta EE) codebase — the process
below is discovery-first by design: identify the repo's real pattern before judging it.

## Step 0 — Establish the baseline before recommending anything

Don't assume Clean/Hexagonal Architecture, DDD, or package-by-feature. Look:
- Is the top-level package split by technical layer (`controller/service/repository`), by
  feature/domain, or hexagonal (`domain/application/adapter`)?
- Within that, is there a consistent sub-convention (e.g. one sub-package per domain inside each
  layer)? Is it followed uniformly, or only in some parts of the codebase?
- What does the codebase's own documentation (README/CLAUDE.md/ADRs) claim the pattern is — and does
  a quick sample of 2-3 real classes actually match that claim? (Docs drift from code; verify, don't
  trust the doc alone.)

**Do not recommend restructuring the baseline (package-by-feature, Hexagonal, a module-boundary
tool like Spring Modulith) as a review finding.** Per the engineering principle "don't recommend a
structural rewrite without evidence of independent-deployment, ownership, scaling, or compliance
pain forcing it": grade new code for **consistency with the pattern already established**, and only
raise a macro-restructuring recommendation as a separately-scoped initiative when there's a concrete
driver (see "Criteria for a new module or service" below) — never as an inline code-review comment
on an unrelated diff.

## Real anti-patterns to check for (illustrative — verify against the actual diff, don't assume)

These recur across Spring Boot codebases regardless of the specific package convention chosen; treat
them as a checklist, and cite the actual file/class you found violating it, not the example below:

| Anti-pattern | What it looks like | Why it matters | What to recommend instead |
|---|---|---|---|
| `@Transactional` on a controller method | A `@RestController` method with `@Transactional` sitting next to `@GetMapping`/`@PostMapping` | Puts the transaction boundary in the web layer; usually masks a `LazyInitializationException` rather than being deliberate | Move the boundary to the service method the controller delegates to; fix the underlying fetch/DTO mapping if lazy-loading is the real issue |
| A service reaching into **another domain's** repository directly | `OrderServiceImpl` autowires `UserRepository`, `PaymentRepository`, `InventoryRepository`, etc., instead of calling those domains' own services | Cross-domain repository reach-through — the calling domain now has a hidden dependency on another domain's persistence shape, bypassing whatever invariants that domain's service enforces | Call the owning domain's service, not its repository |
| Business logic or silent exception-swallowing inside a controller | A controller catches a parsing/validation exception and unilaterally returns a default/empty result instead of a proper error response; a controller clamps/normalizes input instead of delegating that to a validator | Controllers should be thin adapters: parse → delegate → map response; silent behavior changes on invalid input are easy to miss in review | Push the decision into a DTO validator (`@Min`/`@Max`/custom `ConstraintValidator`) or the service, and let invalid input produce a real validation error |
| A mapper (MapStruct or hand-written) calling a repository or service | A `@Mapping`-annotated method resolves extra data via an injected repository inside what's supposed to be a pure transform | Blurs the mapper/service boundary; the mapper is no longer a pure, side-effect-free, easily-unit-testable transform | Resolve the extra data in the service before calling the mapper, or make the enrichment an explicit service method |
| A God-class service | One service class growing far larger than its peers, injecting many unrelated collaborators, becoming the default place new unrelated logic gets bolted onto | Hard to review/test/change safely; a magnet for further unrelated additions | Split along an actual single-responsibility seam if one exists; don't split merely to hit a line-count target |
| Inconsistent controller/versioning convention within the same codebase | Some domains use an interface + versioned-impl split (`FooController` interface, `FooControllerV1` impl); others put `@RestController` directly on one class | New code copying whichever convention happens to be more common further entrenches the inconsistency | Match the convention already used **in the specific domain/module being touched** — don't invent a third pattern, and don't silently retrofit unrelated legacy code in the same change |

## Criteria for introducing a new abstraction (concrete, not vague)

Reject a new interface/factory/strategy/builder/port-adapter unless **at least one** is true — and
say which one in the review:
1. There are **already 2+ concrete implementations** that need to vary independently at runtime.
2. The abstraction is **required to break a compile-time dependency direction** (a lower layer would
   otherwise be forced to import a higher layer's concrete type).
3. A test genuinely needs to substitute the implementation, and a plain class + a mocking framework
   isn't sufficient (e.g. a deliberate choice to leave a composite/facade interface unsealed
   specifically so a fixed-version mocking library can still create a mock, while the real
   exhaustiveness guarantee is enforced one level down on a sealed abstract base — a real, defensible
   pattern, not an accident).
4. An external contract (REST, event, DB) requires a stable seam independent of today's single
   implementation.

"We might need to swap X someday" is **not** sufficient on its own — that's the YAGNI case for
rejecting the abstraction until one of the above becomes concrete.

## Criteria for introducing a new module or service (not just a package)

Do not propose splitting a domain out into a new deployable service without a documented, concrete
driver: an independent scaling need, an independent deploy cadence already blocked by coupling, a
different team owning it, or a compliance/data-isolation requirement. Existing service boundaries
usually reflect real product-concern splits drawn for good reasons — that's a reason those
boundaries exist, not a license to draw more of them without the same kind of justification.

## When to flag that a decision needs a written record (ADR-style)

Recommend capturing the rationale somewhere durable (an ADR if the repo has that convention,
otherwise the ticket/PR description) — don't let it be silently decided in code — when a change:
- Introduces a new cross-cutting infra dependency (new cache, broker, external system integration).
- Breaks or renegotiates a contract another team/service/consumer depends on.
- Deliberately deviates from the established layering baseline (and the deviation is judged
  justified, not accidental).
- Chooses between two non-trivial designs where the reasoning won't be obvious from the diff alone.

If the repo has no ADR mechanism, don't propose creating one as part of an unrelated change — just
ask for the rationale to be captured in the MR/PR description instead.

## Review checklist

- [ ] Controller has no `@Transactional`, no business/validation decision logic, no silent
      exception-swallowing that changes response semantics.
- [ ] Service does not reach into another domain's repository directly — goes through that domain's
      service, or the reach-through is deliberate and justified in the diff/PR.
- [ ] No persistence entity crosses into a controller response, request DTO, or serialized payload.
- [ ] Mapper stays a pure transform — no repository/service calls inside a mapping method.
- [ ] Any new abstraction meets at least one concrete criterion above; state which.
- [ ] New code in a domain that already has an established convention (versioning, layering style)
      follows it rather than inventing a new one.
- [ ] Cross-cutting/contract-breaking changes have a rationale captured somewhere durable.

## Analysis commands

```bash
# Package structure overview
find src/main/java -type d | head -30

# Largest packages / files (potential god package or god class)
find src/main/java -name "*.java" | xargs dirname | sort | uniq -c | sort -rn | head -10
find src/main/java -name "*.java" | xargs wc -l | sort -rn | head -10

# @Transactional on a controller (should be zero)
grep -rl "@Transactional" src/main/java --include="*Controller*.java"

# JPA entity referenced outside the persistence package (needs manual judgement)
grep -rln "import.*\.entity\." src/main/java --include="*Controller*.java" --include="*Dto*.java" --include="*Response*.java" --include="*Request*.java"
```

## Token optimization

For large codebases: `find` for structure first, sample 2-3 domains for pattern-consistency (does
this domain follow the majority convention or an established convention of its own?), grep for the
specific anti-patterns above rather than reading every file.
