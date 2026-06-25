# Rules — `functions/quapp-functions-backend` ("QuaO" platform backend / BFF)

Shared Java conventions (strict layering, naming, Gradle wrapper, `controller/v1/` versioning) live in
`workspace.md` and apply here. This file covers backend-specific detail.

## Responsibility
The central product backend / Backend-For-Frontend. Owns quantum function CRUD + invocation,
projects/workspaces, users & SSO, subscriptions/plans, billing (Stripe), quotas, devices/providers,
scheduling, notifications, audit logs, invoices, AI-model access.

## Stack
- Spring Boot **3.0.5**, **Java 17**, Gradle (wrapper). Gradle root project name = `QuaO`.
- Lombok + MapStruct. PostgreSQL + Spring Data JPA.
- Spring Security OAuth2 (resource server + client). WebSocket + `socket.io-server`.
- Caffeine cache. Resilience4j. Thymeleaf (email/templates). SpringDoc OpenAPI.
- Heavy AWS SDK usage: Braket (quantum), S3, Cognito, Secrets Manager, ECR, SES, SQS, CloudTrail.

## Entry point
`src/main/java/com/citynow/quao/QuaOApplication.java` (sets JVM default timezone to **UTC**).

## Folder structure (`src/main/java/com/citynow/quao/`)
`controller/` (REST, organized by domain e.g. `auth/`, `subscription/`, `billing_account/`,
`functions/`, `quota/`, `webhook/`, `admin/`, `token/`, `invoice/`), `service/`, `repository/`,
`entity/`, `dto/` (very large — one subpackage per domain), `mapper/` (MapStruct), `component/`,
`factory/`, `aspect/`, `schedule/`, `message/` (SQS/JMS), `configuration/` (`aws`, `cognito`, `s3`,
`security`, `cache`, `invocation`, `web`…), `annotation/`, `exception/`, `platform/`, `constants/`,
`utils/`.

## Build / run
```bash
./gradlew build              # build + tests
./gradlew bootRun            # run locally
./gradlew test               # unit tests
```
CI buildspecs present (AWS CodeBuild): `buildspec.yaml`, `unit-test.buildspec.yml`,
`integration-test.buildspec.yml`. Ad-hoc API scripts: `api_testing/` (Postman collection/env),
`trigger_testing.sh`. Testing detail in `testing.md`.

## Config / environment
- Profile-split YAML in `src/main/resources/`: `application.yml` plus ~30 `application-<concern>.yml`
  files (`-aws`, `-cognito`, `-payment`, `-notification`, `-invocation`, `-quota`, `-prefect`,
  `-scheduling`, `-bff`, env profiles `-dev`/`-stg`/`-prd`/`-local`). Also `logback-spring.xml`,
  i18n bundles, email templates, and a `prefect/` dir.
- `SPRING_PROFILES_ACTIVE` selects env + concerns. Secrets via **AWS Secrets Manager**; AWS
  region/Cognito/Stripe/SQS settings live in the concern YAMLs.

## Backend-specific patterns
- Auth: OAuth2 **JWT resource server**, Cognito-backed (`configuration/cognito/`).
- Stripe webhook signature handling (`controller/webhook/StripeWebhookController.java`).
- Resilience4j rate limiting. WebSocket/STOMP + socket.io for live updates.

## Deploy
`k8s/` manifests, `Dockerfile`. Runtime host: `functions-<env>.quapp.cloud`. DB migrations are run
separately by `quapp-migration` (see `migration.md`) **before** this service deploys.

## Pitfalls
- Match **Java 17** when building from a terminal.
- Never return JPA entities from services/controllers — go through MapStruct mappers.
- Schema changes belong in `quapp-migration`, not here (don't rely on `ddl-auto`).
