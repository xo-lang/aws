# Decisions

Architecture decision records, numbered `NNNN-short-title.md`, each with
Status, Context, Decision, Consequences, Alternatives. A reversed decision
gets a new record and the old one is marked `Superseded by NNNN`; none is
deleted.

- [0001](0001-architecture-and-module-layout.md): a core module at the root plus one module per service (`s3/`, tagged `s3/vX.Y.Z`), core packages named so they never collide with a service, effects stated in signatures (Proposed)
- [0002](0002-code-generator.md): the generator, in Xo, reads the pinned api-models-aws JSON AST, plans names once, emits explicit serializers and compiled endpoint rules, committed output (Proposed)
- [0003](0003-core-runtime.md): the hand written core: SigV4/SigV4a, credentials chain, config, retries, endpoint functions, six protocols, event streams, checksums, paginators and waiters (Proposed)
- [0004](0004-api-shape.md): aws-sdk-go-v2's shape in Xo style: `T?` inputs, enums with `Unknown`, per operation error enums, Go's five step middleware (Proposed)
- [0005](0005-testing.md): testing without real AWS: fakes, signing suites, endpoint tests, Smithy protocol tests, emulators behind a localhost-only `Net` (Proposed)
- [0006](0006-xo-gaps.md): Xo language, toolchain and std items for the lead, each with the workaround the SDK uses meanwhile (Proposed)
- [0007](0007-public-repository-license-and-hygiene.md): Apache-2.0 proposed, NOTICE and attribution, trademark disclaimer, public repository hygiene (Proposed)
