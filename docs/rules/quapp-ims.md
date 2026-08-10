# Rules — functions/quapp-ims

The **admin / IMS web UI**. UmiJS Max + React + AntD + TypeScript, same stack and conventions as
`quapp-functions-frontend`. GitLab: `quapp/platform/quapp-ims`.

> ⚠️ **Two repos claim the name `quao-frontend`.** `quapp-ims`'s `package.json` `name` field is also
> `quao-frontend`, identical to `quapp-functions-frontend`. Identify the repo by **folder path**, never
> by package name.

## Why it matters for cross-repo work

`quapp-ims` is a **second frontend consumer of `quapp-functions-backend`**, and it is **not a member of
the GitNexus `quapp` contract group** (that group is backend + functions-frontend + ai-mcp only).

So a clean `route_map` / `api_impact` / contract-registry result **does not prove** a backend route or
DTO change is safe — grep `quapp-ims` by hand as well. This is the single most common way an IMS
regression slips through.

## Pages it owns

Usage, cost and administration screens that do **not** exist in `quapp-functions-frontend`:

`ProviderUsageTime` · `UsageTime` · `CurrentUsage` · `ProjectUsage` · `AdminCostAnalysis` ·
`CostAnalysis` · `AiAssistantUsage` (+ `AiAssistantUsageDetail`) · `BillingAccounts` ·
`BillsPayments` · `PurchaseServices` · `ResourceLimit` · `SystemAdministration` · `AccountSetup` ·
plus the auth flows (`EmailLogin`, `PasswordLogin`, `CallbackSSOToken`, `SignUp`,
`ConfirmRegistration`, `ResetPassword`, `Security`, `PersonalInformation`, `ProfileCompletion`).

If a ticket mentions **Provider Usage Time / Usage Time**, the frontend work is here.

## Structure

Standard UmiJS Max layout, mirroring `quapp-functions-frontend`:
`config/{config.ts,routes.ts,defaultSettings.ts}` · `src/{pages,components,dataSources,constants,contexts,hooks,formiks,wrappers,utils,locales,styles,types}`.

Env globals defined in `config/config.ts` `define`: `BASE_URL`, `MCP_BASE_URL`, `CMS_BASE_URL`.
Note it is **`MCP_BASE_URL`** here, versus `MCP_API_BASE_URL` in `quapp-functions-frontend` — don't
copy env wiring between the two repos blindly.

## Branch model — has extra targets

Beyond the usual `develop` / `staging` / `production`, this repo's `.gitlab-ci.yml` also deploys
**`ctc-staging`** and **`ctc-production`** (a separate CTC tenant deployment). Stages: `build → sast → deploy`.

**Confirm the branch base per fix** — and confirm whether the fix must also land on the `ctc-*` line.
Never default to `develop` (see [git-workflow.md](../../rules/git-workflow.md)).

## Build / dev / test
Uses **`yarn`** (not npm), like the other frontend:
- `yarn start:dev` — dev server against the dev API
- `yarn build` — `max build`
- `yarn lint` (eslint + prettier + `tsc --noEmit`) · `yarn tsc`
- `yarn test` / `yarn test:coverage` (Jest)

**Frontend test exception applies**: per [testing.md](../../rules/testing.md), do not author new Jest
tests for changes here unless explicitly asked — but still run the existing suite and `tsc` before
declaring done.
