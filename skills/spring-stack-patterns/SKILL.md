---
name: spring-stack-patterns
description: Idioms and pitfalls for the Spring/Java data stack — Spring Boot architecture (controllers, services, repositories, REST, exception handling, config), JPA/Hibernate (N+1, lazy loading, fetching, transactions, queries), and structured logging (SLF4J, MDC, JSON). Use when building Spring components, diagnosing JPA performance/LazyInitializationException, or adding logging/tracing.
---

# Spring Stack Patterns

One reference for the Spring-ecosystem layers as they're actually used in these services
(Spring Boot + JPA + SLF4J). Load only the relevant section.

## Routing — which section applies
| If the change involves… | Read |
|-------------------------|------|
| Controllers, services, config, REST design, exception handling, bean wiring | [spring-boot.md](spring-boot.md) |
| Entities, repositories, queries, fetching, transactions, N+1, `LazyInitializationException` | [jpa.md](jpa.md) |
| Logging, MDC/request tracing, structured/JSON logs, AI-friendly log formats | [logging.md](logging.md) |

## Core stance
- Respect the project's **strict layering** — JPA entities never leave the repository layer
  (see `rules/workspace.md`); map to DTOs/domain models via MapStruct.
- Measure before optimizing JPA; most "slow" issues are N+1 or wrong fetch type, not the DB.
- Log at boundaries with MDC context, not inside tight loops.

## References
- For database performance specifically, this skill's [jpa.md](jpa.md) is the source; for
  code-level CPU/memory smells use [code-review](../code-review/SKILL.md).
