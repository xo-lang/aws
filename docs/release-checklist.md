# Release checklist

Steps before the first tag, and before every tag after it. Keep this
current as work finds new ones.

1. **Requires.** Every module's xo.mod requires each module it imports
   from (core 4.2, XO1306). The root requires the service modules its
   packages use (`service/sts` for `credentials/stscreds` and `config`),
   and each service module requires the root. `xo mod tidy` writes them
   (xo ec7332b77 or later; before it, tidy dropped the root's require of
   a nested module, xo-issues entry 7).
2. **Cycle order.** The root and service/sts require each other
   (decision 0003). Tag in order: the root first, then service/sts
   requiring that root tag, then a root tag requiring that sts tag.
3. **No workspace.** Check each module with `--workspace=off`, so a
   missing require fails here rather than for a user.
4. **Gates.** `scripts/gate.sh`, `scripts/check-programs.sh` (the
   examples built natively and run: a program links differently from a
   test), `scripts/check-endpoints-compiled.sh`,
   `scripts/check-public.sh`, and gitleaks over the full history
   (decision 0005, 0007).
5. **Integration.** `scripts/integration-localstack.sh` against
   LocalStack.
6. **Real AWS (owner, 2026-11-04).** After the generator is feature
   complete (paginators, waiters, event streams, SigV4a, docs pass), the
   owner sets up a real AWS account for testing. Before any run, a test
   plan goes to the owner: services and operations, every resource created
   and deleted, a cost estimate, and cleanup on failure. No real AWS
   endpoint, credential or profile is used before that.
7. **Public.** The repository is made public after the real AWS tests
   pass. Until then every push already runs check-public and gitleaks.
8. **First release.** Every published module (the root and the 435
   under `service/`) gets the same version at one commit: the root
   requires `service/sts` at it and each service requires the root at
   it (the generator keeps an existing xo.mod and gives a new service the
   root version sts requires). `scripts/first-release.sh v0.1.0` checks
   the tree and the requires and prints the tags; `--push` creates and
   pushes them, the root first, then service/sts, then the rest. Check it
   first against a scratch clone (`TAG_REMOTE` set to a bare clone, then
   an app that gets the root and two services with no workspace). Later
   releases use `scripts/tag-modules.sh`, which first runs
   `scripts/check-core-requires.sh --typecheck` over the changed
   services against the root it is about to tag (no call of a core
   function, type or field newer than it), then tags the root, raises
   each changed service's `require github.com/xo-lang/aws` to that tag in
   one commit, and tags the services there. Before 2026-11-06 it tagged
   services that still required v0.1.0 while calling newer core
   functions; check a release the same way, against a scratch clone.
9. **CI.** Push `.github/workflows/models.yml` only after the repository
   is public, run it once by hand (a `workflow_dispatch` dry run) and
   report its timings before the first scheduled Wednesday run
   (decision 0008). After the first release, the weekly run tags the
   modules that change; check the first such run's tags by hand.
10. **Xo skips.** When an Xo release reaches a version in
   `scripts/xo-skips.tsv`, remove that entry, and update the README's
   requirements.
