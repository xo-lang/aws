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
4. **Gates.** `scripts/gate.sh`, `scripts/check-endpoints-compiled.sh`,
   `scripts/check-public.sh`, and gitleaks over the full history
   (decision 0005, 0007).
5. **Integration.** `scripts/integration-localstack.sh` against
   LocalStack. Real AWS only with the owner's permission.
