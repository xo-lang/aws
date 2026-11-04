# 0007: Public repository: license, attribution, trademarks, hygiene

Status: Accepted (owner, 2026-11-04; proposed by Xo AWS 1, 2026-11-04)

## Context

github.com/xo-lang/aws is private now and will be made public. Its
generated code is derived from AWS's Smithy models (Apache-2.0), including
the models' documentation text, and its tests copy Apache-2.0 test suites
(the Smithy protocol tests, the aws-c-auth signing suite). The owner
decided the README says up front that the project is a community SDK, not
affiliated with or endorsed by AWS, with the trademark notice, and no AWS
logos.

## Decision

- **License: Apache-2.0 for the whole repository** (owner, 2026-11-04).
  Reasons: the generated code and doc comments derive from
  Apache-2.0 models; the copied test suites are Apache-2.0; aws-sdk-go-v2
  and smithy-go are Apache-2.0, which users expect of an AWS SDK; and
  Apache-2.0's patent grant suits an SDK companies will adopt. The Xo
  repository itself is MIT; MIT here would also work, with the Apache-2.0
  parts kept under their own license and NOTICE, but two licenses in one
  module is harder for users to audit.
- `LICENSE` (Apache-2.0 text), `NOTICE` (this project's copyright line,
  then each upstream: api-models-aws, the partitions table's source,
  smithy-lang/smithy protocol tests, awslabs/aws-c-auth signing suite,
  each with its copyright line as its NOTICE gives it), and a
  `THIRD_PARTY_NOTICES` file if any MIT or BSD code is ported (for
  example a JMESPath subset or CRC tables).
- Every generated file's header names its model and the pinned models
  commit (0002).
- README first lines: the owner's disclaimer, verbatim. No AWS logos or
  service icons anywhere; AWS service names appear only as names, as
  needed to identify what a module talks to.
- **Hygiene for a public repository:** no account ids (except the
  documented example `123456789012`), real bucket names, ARNs of real
  accounts, IP addresses (except loopback and the documentation ranges),
  host names of the owner's machines, email addresses other than the
  commit author's, keys, tokens, or local paths. `scripts/check-public.sh`
  and gitleaks run over the whole history before every push (0005). A
  finding is fixed before the push; pushed history is never rewritten.
- Commits carry no attribution lines and no em dashes.

## Consequences

The repository can be flipped to public without a history rewrite, and
its licensing is clear to users and to AWS.

## Alternatives

- MIT, matching Xo: fine for hand written code, awkward for code derived
  from Apache-2.0 models (above).
- Not committing generated code (users run the generator): avoids most
  derived text in the repository, but every user would need the models and
  the generator; rejected in 0001.
