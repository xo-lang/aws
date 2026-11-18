# 0011: Credential discovery, config and file uploads in modules of their own

Status: Accepted (owner, 2026-11-14, through the lead), as one rule for
every Xo cloud SDK: [gcp decision
0014](https://github.com/xo-lang/gcp/blob/main/docs/decisions/0014-credential-modules.md).
This records how aws applies it, in v0.3.0.

## Context

Xo records effects per module: `xo.lock` holds one effects line per
required module, the union of what any package of it may reach. Up to
v0.2.1 the root module's line was `clock, env, fs, net.dial, proc,
rand`, from `config`, `credentials` and three root files
(`process.xo` runs a `credential_process`, `tokenfile.xo` reads and
writes token files, `upload.xo` reads a file to upload), so every
program that called S3 with keys it held accepted reading the
environment, files and running programs.

## Decision

The root module and every service module reach only `clock`,
`net.dial` and `rand`. What reaches more is a module of its own, at the
directory it has today, so import paths do not change:

- `github.com/xo-lang/aws/credentials` (with `container`, `imds`,
  `ssocreds`, `stscreds`): `from_env`, the chain, reading and watching
  token files (`load_token_file`, `token_file_or_empty`, `watch`,
  `flush`, `reload`) and running a `credential_process`
  (`run_process`, `start_process`).
- `github.com/xo-lang/aws/config`: `load_default_config`, and the two
  task starters that were methods on `aws.Config`:
  `config.watch_token_files(cfg, ...)` and
  `config.run_credential_processes(cfg, ...)`.
- `github.com/xo-lang/aws/fileio`: `upload_file`.

The root keeps the types and what needs no effect, as aws-sdk-go-v2
keeps `aws.Credentials` and `aws.CredentialsCache` in its root:
`StaticProvider` and `static_provider` (`credentials.static_provider`
forwards to it), `SessionCache` (S3 Express), `TokenFile` (the token,
`fixed_token`, `get`, `set`), `CredentialProcess` (`retrieve`,
`parse_process_output`) and `Upload` with `upload_reader` and the new
`upload_opener(open, length, done)`, which retries any body the program
can give afresh. Owner's question 2 of gcp 0014: `SessionCache` and
`retrieve` are in the root `aws` package; the effects check shows the
root at `clock,net.dial,rand` with them, so no `aws/credcache`.

The root no longer requires `service/sts` (only `credentials/stscreds`
and `config` use it), which ends the root and sts require cycle of
decision 0003: v0.3.0 tags every module at one commit with
`scripts/release-all.sh`, and `scripts/check-release.sh` rehearses it
and checks an app's `xo.lock` effects for the root, s3 and sts.

## Consequences

- A program that uses `config` or `credentials` adds their requires;
  one that uploads files adds `fileio`. Each shows its wider effects by
  name in `xo audit`.
- `cfg.watch_token_files(...)` and `cfg.run_credential_processes(...)`
  become `config.watch_token_files(cfg, ...)` and
  `config.run_credential_processes(cfg, ...)`; `aws.upload_file`
  becomes `fileio.upload_file` with the same arguments.
