# Decisions

Architecture decision records, numbered `NNNN-short-title.md`, each with
Status, Context, Decision, Consequences, Alternatives. A reversed decision
gets a new record and the old one is marked `Superseded by NNNN`; none is
deleted.

- [0001](0001-architecture-and-module-layout.md): a core module at the root plus one module per service (`s3/`, tagged `s3/vX.Y.Z`), core packages named so they never collide with a service, effects stated in signatures (Accepted)
- [0002](0002-code-generator.md): the generator, in Xo, reads the pinned api-models-aws JSON AST, plans names once, emits explicit serializers and compiled endpoint rules, committed output (Accepted)
- [0003](0003-core-runtime.md): the hand written core: SigV4/SigV4a, credentials chain, config, retries, endpoint functions, six protocols, event streams, checksums, paginators and waiters (Accepted)
- [0004](0004-api-shape.md): aws-sdk-go-v2's shape in Xo style: `T?` inputs, enums with `Unknown`, per operation error enums, Go's five step middleware (Accepted)
- [0005](0005-testing.md): testing without real AWS: fakes, signing suites, endpoint tests, Smithy protocol tests, emulators behind a localhost-only `Net` (Accepted)
- [0006](0006-xo-gaps.md): Xo language, toolchain and std items for the lead, each with the workaround the SDK uses meanwhile (Accepted)
- [0007](0007-public-repository-license-and-hygiene.md): Apache-2.0, NOTICE and attribution, trademark disclaimer, public repository hygiene (Accepted)
- [0008](0008-continuous-integration.md): the weekly models workflow: newest Xo release, model update, every check, merge and tag on green, pull request and issue on red, no AWS in CI (Accepted)
- [0009](0009-streamed-uploads.md): streamed request bodies: `aws.Upload` from a file (retried from its start) or a reader (sent once), S3 uploads in aws-chunked with a trailing checksum, `aws.auth#unsignedPayload` honored (Accepted)
- [0010](0010-float32-members.md): Smithy `float` members as `Float32`, each protocol rounding as Go does (Accepted)
- [0011](0011-credential-modules.md): credential discovery, config and file uploads in modules of their own, the root and services at clock, net.dial and rand (gcp 0014, all SDKs; v0.3.0) (Accepted)
