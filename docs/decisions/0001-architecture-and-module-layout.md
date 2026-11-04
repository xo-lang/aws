# 0001: Architecture and module layout

Status: Accepted (owner, 2026-11-04; proposed by Xo AWS 1, 2026-11-04)

## Context

The owner decided (2026-11-04) to cover the whole AWS API surface, generated
from AWS's Smithy models (github.com/aws/api-models-aws, Apache-2.0), with a
hand written core, one module per service in this repository, and an API
that mirrors aws-sdk-go-v2. Xo modules (spec/core.md 4.2) may live in a
subdirectory of a repository: `github.com/xo-lang/aws/s3` is the directory
`s3/`, its versions are the tags `s3/vX.Y.Z`, and a directory holding its own
`xo.mod` is never part of the module around it. A package's local name is
its last path segment with `-` replaced by `_`; a keyword or an invalid
identifier needs `as` (XO0602).

## Decision

### Modules

| Directory | Module path | Contents | Published |
|---|---|---|---|
| `/` | `github.com/xo-lang/aws` | the core runtime (0003), split into packages | yes, tags `vX.Y.Z` |
| `/<service>/` | `github.com/xo-lang/aws/<service>` | one generated client package per service | yes, tags `<service>/vX.Y.Z` |
| `/codegen/` | `github.com/xo-lang/aws/codegen` | the generator, written in Xo (0002) | no (tagged only for reproducibility) |
| `/internal/protocoltest/` | own `xo.mod` | generated protocol compliance test services (0005) | no |
| `/examples/` | own `xo.mod` | small programs against emulators | no |

The core's packages (all in the root module, so one version moves them
together; paths relative to `github.com/xo-lang/aws`):

```
(root)          package aws: Config, Credentials, Region, errors, options
sigv4/          SigV4 signing
sigv4a/         SigV4a signing (later)
credentials/    providers: static, env, shared files, process, sso,
                web identity, ecs, imds, the default chain, caching
config/         load_default_config: region, profile, files, chain
retry/          standard and adaptive retry strategies
endpoints/      the rules engine's standard library and partitions
protocol/...    restjson, restxml, awsjson, query, ec2query
eventstream/    the event stream framing, signing, and decoder
transport/      the HTTP pipeline (middleware stack, 0004)
checksum/       CRC32, CRC32C, CRC64NVME, SHA1, SHA256, aws-chunked
internal/...    shared helpers not part of the API
```

Core packages and service modules share the root directory, so their
names must not collide. Go's core uses `signer/v4`, but `signer` is also
an AWS service (AWS Signer), and a version segment (`v4`) is a poor local
name; the core uses `sigv4` and `sigv4a` (`use
github.com/xo-lang/aws/sigv4` binds `sigv4`). The generator keeps the list
of core directory names and refuses to emit a service whose directory is
one of them (0002), so a future service named like a core package is a
loud error to resolve here, by a suffix, not a silent overwrite.

### Service directory and package names

The directory is the model's `sdkId` lower cased with spaces removed, the
rule aws-sdk-go-v2 uses (`API Gateway` is `apigateway`, `ACM PCA` is
`acmpca`). The generator then checks each name:

1. `-` becomes `_` for the local name (spec 4.1); the generator also
   strips any other character outside `[a-z0-9_]`.
2. A name that starts with a digit, or that is one of Xo's 28 keywords
   (`as break const continue defer else ensures enum fn for if in
   interface invariant let match pub requires return scope select struct
   test type use uses var while`), or a predeclared identifier (`true
   false self target fault dbg Ok Err Some None`), gets a suffix `svc`
   (`typesvc`). No current sdkId collides (checked when the generator
   lands, 0002, with a test over every model), so the rule exists for
   future services.
3. Two services mapping to one name is a generator error, never a silent
   overwrite.

### Versioning and releases

- Core and services are versioned separately, as in aws-sdk-go-v2
  (`service/s3/v1.x`). Each service `xo.mod` requires the minimum core
  version its generated code needs; minimal version selection (spec 4.2)
  picks the highest required core.
- Every service starts at `v0.1.0`; `v1.0.0` of the core and of a service
  happens only after the owner accepts the API as stable. Before v1 a
  minor release may break (spec 4.2 Releases).
- `xo publish --check` runs for every changed module before a tag; a
  generated change that breaks an export (an AWS model change that renames
  a member, which AWS treats as breaking and does not do) fails the check
  and is investigated, not forced.
- A repository `xo.work` lists the core and every service so local
  development builds services against the core in the working tree. It is
  committed (spec 4.2 allows a monorepo to commit one). Release builds
  (`xo build --release`) refuse a workspace override (XO1308), so the
  release script runs with `XO_WORK=off`.
- Generated code is committed, as in aws-sdk-go-v2, so a user fetches a
  tag and builds with no generator and no models. A model update is one
  commit per batch: the pinned models commit (0002), regenerated output,
  and changelog lines per service.

### Effects

Xo tracks effects in signatures (spec 6). The SDK uses them to state what
it does:

- Loading configuration `uses (env, fs.read)` and takes the `Env` and `Fs`
  capabilities explicitly; a test passes `FakeEnv` and `MemFs`, so no test
  can read the developer's real shared config or credentials files.
- An API call `uses (net.dial, clock, rand)`: the network, the signing time
  and retry sleeps, and retry jitter. Nothing else. A credentials provider
  that refreshes (SSO, web identity, IMDS) also only needs `net.dial` and
  `clock` at call time; its file reads happened at load time.
- Users may set an effect ceiling (`require github.com/xo-lang/aws/s3
  v0.1.0 uses net.dial, clock, rand, env, fs.read`) and it holds.

## Consequences

- One repository, many modules, each tagged on its own; a service upgrade
  never forces another service's upgrade.
- The repository is large (aws-sdk-go-v2's service tree is several hundred
  MB of generated Go). Tags of one service fetch only that directory's
  tree (spec 4.2), so users do not pay for it.
- The core API is a compatibility surface for every service; changes to it
  are reviewed as such (0004).

## Alternatives

- One module for everything: simplest to tag, but every user fetches and
  every check loads hundreds of services. Rejected by the owner's
  decision 2.
- A separate repository per service: what aws-sdk-go v1 avoided and v2
  does not do either; cross service model updates would need hundreds of
  pushes. Rejected.
- Copy Go's `signer/v4` directory names: the local name `v4` is legal but
  meaningless at a call site. Rejected for `sigv4`.
