---
name: security-review
description: Java security checklist covering OWASP Top 10, input validation, injection prevention, and secure coding. Works with Spring, Quarkus, Jakarta EE, and plain Java. Use when reviewing code security, before releases, or when user asks about vulnerabilities.
---

# Security Audit Skill

Security checklist for Java applications based on OWASP Top 10 and secure coding practices. Load
only the reference section relevant to what the diff actually touches — don't read all three for a
one-file logging change.

> **Model routing:** opus-class ([`../../docs/rules/model-routing.md`](../../docs/rules/model-routing.md)) —
> security review is never routed below opus. When invoked from `/ship-task` (which runs on sonnet),
> run this review in the **`deep-reviewer`** agent (`../../agents/deep-reviewer.md`, pinned to opus)
> with the security lens + this checklist, and merge its findings. **If code-review is also spawning
> a deep-reviewer for the same diff, fold this checklist into that ONE agent instead of spawning a
> second** — a separate agent re-reads the whole diff (~80-90k tokens) for no extra coverage.
>
> **GitNexus taint layer** ([`../../docs/rules/gitnexus.md`](../../docs/rules/gitnexus.md)): `explain` surfaces
> persisted source→sink findings only after `analyze --pdg` (not built by default). If available, use
> it as a *lead generator* — absence of a finding is never proof of safety; the checklist still runs.

## When to Use
- Security code review
- Before production releases
- User asks about "security", "vulnerability", "OWASP"
- Reviewing authentication/authorization code
- Checking for injection vulnerabilities

## Step 0 — deterministic secret scan (always first)

Before any LLM review, run the bundled script against each touched repo:

```sh
bash .claude/skills/security-review/secret-scan.sh <repo-dir>
```

It scans added lines in the uncommitted diff + untracked files for high-confidence credential
shapes (AWS/GitLab/GitHub/Anthropic/Stripe/Slack tokens, private keys, JWTs) and `.env` files.
Exit 1 = BLOCKER (never commit); WARN lines need human judgment. The script is the floor, not the
ceiling — a clean scan does not skip the checklist below (it can't see logic flaws, weak crypto,
or secrets echoed to logs).

---

## OWASP Top 10 Quick Reference

| # | Risk | Java Mitigation |
|---|------|-----------------|
| A01 | Broken Access Control | Role-based checks, deny by default |
| A02 | Cryptographic Failures | Use strong algorithms, no hardcoded secrets |
| A03 | Injection | Parameterized queries, input validation |
| A04 | Insecure Design | Threat modeling, secure defaults |
| A05 | Security Misconfiguration | Disable debug, secure headers |
| A06 | Vulnerable Components | Dependency scanning, updates |
| A07 | Authentication Failures | Strong passwords, MFA, session management |
| A08 | Data Integrity Failures | Verify signatures, secure deserialization |
| A09 | Logging Failures | Log security events, no sensitive data |
| A10 | SSRF | Validate URLs, allowlist domains |

## Routing — which reference applies

| If the diff touches… | Read |
|-----------------------|------|
| Request/DTO validation, JPQL/native/JDBC queries, deserialization of untrusted data | [references/input-validation-and-injection.md](references/input-validation-and-injection.md) — Input Validation, SQL Injection Prevention, Secure Deserialization |
| Rendered/returned output, forms, response headers | [references/web-output-protections.md](references/web-output-protections.md) — XSS Prevention, CSRF Protection, Security Headers |
| Login/session/authorization code, secrets/config, logging statements, dependency versions | [references/auth-secrets-and-deps.md](references/auth-secrets-and-deps.md) — Authentication & Authorization, Secrets Management, Logging Security Events, Dependency Security |

---

## Security Checklist

### Code Review

- [ ] Input validated with allowlist patterns
- [ ] SQL queries use parameters (no concatenation)
- [ ] Output encoded for context (HTML, JS, URL)
- [ ] Authorization checked at service layer
- [ ] No hardcoded secrets
- [ ] Passwords hashed with BCrypt/Argon2
- [ ] Sensitive data not logged
- [ ] CSRF protection enabled (for browser apps)

### Configuration

- [ ] HTTPS enforced
- [ ] Security headers configured
- [ ] Debug/dev features disabled in production
- [ ] Default credentials changed
- [ ] Error messages don't leak internal details

### Dependencies

- [ ] No known vulnerabilities (OWASP check)
- [ ] Dependencies up to date
- [ ] Unnecessary dependencies removed

---

## Related Skills

- `code-review` - General code review
- `spring-stack-patterns` - Secure logging (logging section)
