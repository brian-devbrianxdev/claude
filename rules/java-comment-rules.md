# Rules — Java Comment Standards

Authoritative comment policy for all Java (and TypeScript/frontend) code in the workspace.
These rules extend and supersede the brief Phase 2 note in `java.md`.

## Core Principle

> **Code explains WHAT. Comments explain WHY. Javadoc explains CONTRACT. Git explains HISTORY.**

---

## The Rules

### 1. Comments MUST explain WHY, not WHAT
- Do not describe behavior that is already obvious from the code.
- Use comments to explain intent, reasoning, constraints, trade-offs, or non-obvious behavior.

### 2. Prefer self-documenting code over comments
- Use meaningful class, method, and variable names.
- Extract complex logic into well-named methods instead of explaining poorly structured code with comments.

### 3. Comment business rules when they are not obvious
```java
// Trial is only available for the user's first subscription.
```

### 4. Comment workarounds and unusual technical decisions
Explain:
- Why the workaround exists.
- What constraint caused it.
- When applicable, what condition would allow it to be removed.

### 5. Use Javadoc for contracts, not implementation details
Javadoc is appropriate for:
- Public APIs
- Interfaces
- Shared/reusable components
- Non-obvious method contracts
- Important parameters, return values, side effects, and exceptions

### 6. Do NOT add redundant comments  ❌
```java
// Get user by ID
User user = userRepository.findById(userId);
```

### 7. Do NOT use comments to compensate for bad naming  ❌
```java
int d; // number of retry days
```
Better: `int retryDelayDays;`

### 8. Keep comments synchronized with the code
- When behavior changes, update or remove related comments.
- Incorrect/outdated comments are worse than no comments.

### 9. Never keep commented-out code  ❌
- Delete unused code.
- Use Git history when old implementations are needed.

### 10. TODO/FIXME comments must be actionable
Avoid:
```java
// TODO fix this
```
Prefer:
```java
// TODO(PQF-1234): Remove fallback after legacy subscriptions are migrated.
```

### 11. Explain important edge cases and defensive logic
```java
// Metadata may be absent for subscriptions created before the migration.
```

### 12. Explain intentional behavior that may look like a bug
```java
// Intentionally return an empty list instead of throwing to preserve API compatibility.
```

### 13. Do not write comments for standard framework behavior  ❌
Avoid explaining obvious Spring/Java annotations or common language constructs.

### 14. Keep comments concise and close to the relevant code
- Avoid long essays inside implementation code.
- If extensive explanation is required, use technical documentation or an ADR.

### 15. Comments must remain professional and factual
- No personal notes, conversations, jokes, blame, or temporary debugging information.

---

## Application scope
These rules apply to:
- All `.java` files in this workspace (enforced by `rules/java.md` Phase 2)
- All `.ts` / `.tsx` files (same principle; frontend has no Jest test requirement per `testing.md`)

## Relationship to other rules
- **`java.md` Phase 2** — the write-time gate; now references this file for the full policy.
- **`code-review` standards lens** — uses these rules when reviewing Java/TS comments.
- **`java-coding-standards` (archived)** — predecessor; this file supersedes its comment section.
