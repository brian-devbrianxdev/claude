---
name: code-review
description: Review REST API contracts for HTTP semantics, versioning, backward compatibility, and response consistency. Use when user asks "review API", "check endpoints", "REST review", or before releasing API changes.
---

# API Contract Review Skill

Audit REST API design against **the target repo's own established convention** first, then against
universal HTTP/REST correctness rules. Applies to any Spring Boot (or Jakarta EE) REST API.

## Step 0 — Establish the repo's own convention before grading

- How are error responses shaped today? Is there a `@ControllerAdvice`/`@ExceptionMapper` funneling
  exceptions into one consistent body, or is it ad hoc per controller? A new failure mode should map
  into the existing funnel, not get a bespoke try/catch in the controller.
- Is there a versioning convention already in use (`/v1/` path segment, header-based, an
  interface+impl split per version)? If yes, is it applied consistently, or only in parts of the
  codebase? Match whatever convention the **specific domain/module being touched** already uses —
  don't introduce a third pattern, and don't silently retrofit unrelated legacy endpoints to "fix"
  an inconsistency in an unrelated change.
- Is OpenAPI/SpringDoc documentation curated (grouped, tagged with constants) or ad hoc? A new
  endpoint should follow whatever curation convention already exists.
- **Is there a shared/generated client between this API's producer and its consumers** (a codegen'd
  SDK, a shared DTO module), or does each consumer hand-maintain its own copy of the contract? If
  there's no generated client, a "breaking" change doesn't fail any build — it fails silently at
  runtime in the consumer. In that case, treat "did you check every known consumer" as a
  **Blocker**-tier review question for any field rename/removal/type-change, not a suggestion.

## HTTP verb / status-code semantics (universal)

| Verb | Use for | Idempotent |
|---|---|---|
| GET | retrieval, no side effects | Yes |
| POST | create, or a non-idempotent action | No |
| PUT | full replacement | Yes |
| PATCH | partial update | Depends on impl |
| DELETE | remove | Yes |

Common mistake to flag: **200 with an error body** (`{"status": "error", ...}` returned with HTTP
200) — if the repo already has a consistent exception-handling funnel, a new hand-rolled
try/catch-and-return-200-with-error-map in a controller is a regression against the established
pattern, not a stylistic nit.

| Code | Use for | Common mistake |
|---|---|---|
| 200 / 201 / 204 | success (retrieval / creation / no body) | Using 200 for creation without a `Location` header |
| 400 | invalid input, validation failure | Using it for "not found" |
| 401 vs 403 | not authenticated vs authenticated-but-forbidden | Conflating the two |
| 404 | resource doesn't exist | Using 400 |
| 409 | conflict / concurrent modification | Using 400 |
| 422 | syntactically valid, semantically invalid | Using 400 |
| 500 | unexpected server error | Exposing a stack trace in the body |

## Request/response design

- **No persistence entity in a request or response DTO** — this holds regardless of what the
  codebase calls its persistence layer (`entity/`, `model/`, `domain/`); a DTO exposing lazy
  collections, internal IDs, or password hashes is the same bug under any naming convention.
- **Collections are paginated** if the underlying data can grow unbounded — `List<T> findAll()` on a
  table with no natural cap is a real finding, not a nit.
- **Response shape consistency**: pick one convention (always-wrapped vs. always-raw for
  collections; object for counts/stats) and check new endpoints follow it, rather than introducing a
  second shape.

## Idempotency and resilience for outbound calls

Any endpoint that triggers a **write** on an external system (payment, provisioning, a third-party
API) should be checked for: is the operation safe to retry, and does the caller have a way to avoid
double-submission on a timeout (idempotency key, natural dedup key)? Don't assume "the external
service is reliable" — check whether retry/circuit-breaker protection actually wraps the call path
in question, or only wraps a different, unrelated internal call path in the same codebase (a common
gap: resilience patterns get added where they were first needed and don't automatically extend to
every subsequent external integration).

## Backward compatibility — breaking vs. safe

| Change | Breaking? |
|---|---|
| Remove endpoint / remove response field / rename field / change field type / change URL path | Yes |
| Add optional request field / add response field / add new endpoint / add new optional query param | No |
| Add a **required** request field | Yes, unless defaulted |

## Review checklist

- [ ] Error path uses the repo's existing exception-handling convention, not a bespoke one.
- [ ] Endpoint matches the versioning convention already used **in that domain/module**.
- [ ] No persistence entity in the request/response DTO.
- [ ] Collections are paginated if unbounded.
- [ ] No 200-with-error-body pattern introduced.
- [ ] Any rename/removal/type-change has a corresponding consumer check, cited concretely (not "should be fine") — especially if there's no shared/generated client.
- [ ] New docs/annotations follow the repo's existing OpenAPI curation convention, if one exists.

## Token optimization

```bash
# List controllers touched
git diff --name-only | grep -i controller

# Check for entity leaks into a controller/DTO
grep -rn "entity" --include="*.java" -- $(git diff --name-only | grep -iE 'controller|dto')

# Check for the 200-with-error anti-pattern
grep -rni "ResponseEntity.ok" --include="*.java" -- $(git diff --name-only) | grep -i error

# Cross-repo/cross-consumer check for a renamed/removed field or path (run in the consumer repo)
grep -rn "<oldFieldOrPathName>" src/
```
