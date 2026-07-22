# Rules — Automated architecture enforcement (decision guide)

Read this when: designing a new module/domain boundary, deciding whether a layering violation found
in review is worth escalating to an automated gate, or evaluating whether to wire ArchUnit or Spring
Modulith into a Java repo's build. Applies to any Java/Spring Boot codebase — the decision framework
below is discovery-first: what tool fits depends on the repo's actual package layout, not on which
tool is more fashionable.

## Why automated enforcement, not just documentation

A layering rule that lives only in a README/CLAUDE.md decays silently as a codebase and team grow —
no single reviewer can manually re-verify every dependency in every diff. If a review pass finds a
layering rule that's written down but not consistently followed (e.g. transaction boundaries
sometimes on controllers, a service sometimes reaching into another domain's repository), that's the
signal to make the rule checkable, not to restate it more emphatically in a doc.

## Decision: ArchUnit vs. Spring Modulith — check the package layout first

| | ArchUnit | Spring Modulith |
|---|---|---|
| Fits a **layer-first** package structure (`controller/service/repository` as top-level siblings) | **Yes, as-is** — expresses "controller may not be accessed by X", "no class in `service` may depend on another domain's `repository`" against the existing layout | **No** — a "module" is defined as a direct sub-package of the application's root package; a layer-first repo would need every domain repackaged to the top level first |
| Fits a **domain/feature-first** package structure already (`order/`, `payment/`, `user/` at the top level, each containing its own controller/service/repository) | Works too, but adds less value — the domain boundary already exists structurally | **Good fit** — module boundaries can be verified and documented with minimal extra structure |
| Adoption cost on a layer-first repo | Add a test-scope dependency + one JUnit 5 test class | Repackage the entire tree so domains become top-level packages — invasive, high-blast-radius |
| What it buys | Enforces whatever layering rule is already policy | Layering enforcement **plus** module-to-module encapsulation, generated module docs/diagrams, event-based cross-module integration testing |

**Default recommendation for a layer-first codebase: adopt ArchUnit, don't pursue Spring Modulith.**
The Modulith payoff (module encapsulation, generated docs) rarely justifies repackaging an entire
existing codebase unless there's already a concrete pain point — a domain that genuinely needs to be
extracted into its own service, a recurring cross-domain-reach-through problem that a lint rule alone
isn't stopping, or a team-ownership conflict that only package-level encapsulation would resolve.
Revisit the decision when one of those becomes concrete, not preemptively.

## Concrete ArchUnit rules to write

Dependency (test scope, JUnit 5): `com.tngtech.archunit:archunit-junit5` (verify current version
against Maven Central before pinning). Wire as a normal test class, e.g.
`src/test/java/.../architecture/LayeringArchitectureTest.java`, using
`@AnalyzeClasses(packages = "<app base package>")` + `@ArchTest` static `ArchRule` fields — this runs
inside the default test task, no separate plugin/build step needed.

```java
@AnalyzeClasses(packages = "com.example.app")
class LayeringArchitectureTest {

    @ArchTest
    static final ArchRule entities_stay_in_persistence_layer =
        noClasses().that().resideOutsideOfPackage("..repository..")
            .should().dependOnClassesThat().resideInAPackage("..entity..");

    @ArchTest
    static final ArchRule controllers_are_not_transactional =
        noClasses().that().resideInAPackage("..controller..")
            .should().beAnnotatedWith(Transactional.class);

    @ArchTest
    static final ArchRule services_do_not_reach_other_domains_repositories =
        // Express per-domain, e.g. one rule per domain pair that should stay isolated —
        // ArchUnit has no single primitive for "a service may only depend on its own
        // domain's repository" without enumerating the domains explicitly.
        noClasses().that().resideInAPackage("..service.orders..")
            .should().dependOnClassesThat().resideInAPackage("..repository.payments..");

    @ArchTest
    static final ArchRule mappers_do_not_call_repositories =
        noClasses().that().resideInAPackage("..mapper..")
            .should().dependOnClassesThat().resideInAPackage("..repository..");
}
```

Notes:
- **Freeze known violations first**, don't block the build on day one. Wrap the initial rollout in
  `FreezingArchRule.freeze(...)` so pre-existing violations found during a review pass don't
  immediately fail the build — freezing lets the test pass on today's code while blocking any *new*
  violation, matching the Clean-as-You-Code philosophy (gate new code, don't demand an immediate
  legacy rewrite — see `quality-gates.md`). Un-freeze each violation only when it's deliberately
  fixed.
- The cross-domain-repository rule must be written **per-domain**, not as one blanket rule — there
  is no single ArchUnit primitive for "a service may only depend on its own domain," so enumerate the
  actual domain pairs that should stay isolated.
- Before adding ArchUnit (or any new static-analysis tool), **check the build file for tooling
  already configured** (SonarQube, JaCoCo, Checkstyl, PMD, SpotBugs, Error Prone) — adding an
  overlapping linter produces duplicate/conflicting findings, not additional safety. See
  `quality-gates.md`.

## Google Style substance worth enforcing even without a formatter/linter tool

Content rules, not whitespace — a reviewer can and should check these by eye regardless of whether
any tool enforces them:
- No wildcard imports.
- `@Override` on every legal override (interface impl, superclass override, record accessor).
- Never silently swallow a caught exception — log, rethrow, or leave an explicit comment on why
  nothing is done; a caught `InterruptedException` specifically must call
  `Thread.currentThread().interrupt()` if not rethrown.
- One top-level class per file; overloaded methods of the same name grouped together.
- `UPPER_SNAKE_CASE` reserved for genuinely deeply-immutable `static final` constants — a
  `static final` field of a mutable type (array, `List`, mutable POJO) is not a "constant" by this
  rule and shouldn't be named like one.

## Tooling to weigh carefully before adopting (checklist, not a blanket recommendation)

- **Checkstyle / PMD / SpotBugs**: check first whether SonarQube (or an equivalent) is already
  configured — its default ruleset overlaps significantly with these tools' catalogues. Adding one of
  these on top of an existing Sonar gate needs a specific reason (a rule Sonar doesn't cover), not
  "more tools = more safety."
- **Error Prone**: valuable compile-time bug-pattern catcher, but has a documented JDK-host-version
  ceiling for older JDKs (roughly: JDK 11 host caps around Error Prone 2.31, JDK 17 host caps around
  2.32–2.42, JDK 21+ can run current versions — verify against current docs before pinning) and an
  undocumented interaction with Lombok's annotation-processor ordering — spike this on a throwaway
  branch before adopting, don't add it speculatively to a build shared by a whole team.
- **Spotless / google-java-format**: lower-risk than the above (pure formatting), but still a real
  build change (adds a plugin, changes what `./gradlew build` does) — treat as its own small,
  explicitly-approved change, not bundled into an architecture-enforcement rollout.
- **A dependency-vulnerability scanner** (OWASP Dependency-Check or equivalent): check first whether
  the repo's CI already runs a container/image scan (Trivy or similar) that covers the same ground —
  if one exists but isn't actually gating merges (branch-restricted, `allow_failure`, or a dead
  `rules:` condition), fixing that is usually higher-leverage than adding a second, overlapping SCA
  tool.
