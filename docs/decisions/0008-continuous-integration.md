# 0008: Continuous integration: the weekly models run

Status: Accepted (lead, 2026-11-05; written by Xo AWS 1, 2026-11-05)

## Context

The clients are generated from AWS's models (api-models-aws), which
change most weekdays, and are committed (decision 0001). The SDK must
also keep working with the Xo releases its users install, not only with
Xo's main branch. Nothing in the repository may need AWS credentials or
call AWS outside the owner's own real AWS runs (docs/real-aws-tests.md).

## Decision

- One workflow, `.github/workflows/models.yml`, on standard GitHub-hosted
  runners (ubuntu-latest): weekly on Wednesdays at 06:00 UTC
  (`0 6 * * 3`), and by hand (`workflow_dispatch`, a dry run by default).
- It installs the newest public Xo release (`scripts/install-xo.sh`,
  checked against the release's SHA256SUMS; a dispatch can name one).
  Tests that need a newer Xo than the one installed are left out with
  their reason printed (`scripts/xo-skips.tsv`, `scripts/apply-xo-skips.sh`):
  today the Transcribe duplex test and the DynamoDB with `select` test,
  both until 0.40.0.
- `scripts/update-models.sh` moves the pin in `codegen/models.lock` to
  the newest api-models-aws commit and regenerates every client.
- The checks: the gate, every service regenerated unchanged and type
  checked, the endpoint rules tests, the integration tests against
  LocalStack in Docker, check-public and gitleaks (the history, and the
  regenerated files before they are committed). Each step's time goes to
  the run's summary (`scripts/ci-step.sh`).
- Caches: Xo's build cache (keyed by the Xo version and the sources), and
  the fetched models and protocol tests (keyed by their locks).
- Green with changed models: the update is committed on a
  `models/<commit>` branch, its pull request is merged, and the published
  modules that changed are tagged (`scripts/tag-modules.sh`): a minor
  version when the change adds an operation, a type or a module, a patch
  otherwise; the root and service/sts in the release checklist's order.
  A module with no tag yet waits for the first release, made by hand.
- Red: the update's pull request stays open (when the models changed),
  and an issue links the run and its timings.
- No AWS credentials, secrets or AWS endpoints in CI: the only token is
  the run's own `GITHUB_TOKEN`.
- The workflow is pushed only once the repository is public (the
  runners' minutes); the first run is a `workflow_dispatch` dry run whose
  timings are reported before the first scheduled run.

## Consequences

- A model change that breaks generation, a check or the public hygiene
  rules stops at a pull request and an issue; nothing is tagged.
- A new Xo release that breaks the SDK shows up within a week as an
  issue, even when the models did not change.
- The skip list must shrink as releases catch up: an entry whose version
  is released is removed with that release.

## Alternatives

- **A pull request per model update, merged by hand.** Rejected: the
  checks are the review, and AWS ships most weekdays.
- **Testing against Xo main.** Rejected for the weekly run: users install
  releases. The gate on the lead's machines already runs Xo main.
- **Daily runs.** Rejected for now: weekly is the cadence the lead set
  for tags, and a daily run would mostly repeat the same checks.
