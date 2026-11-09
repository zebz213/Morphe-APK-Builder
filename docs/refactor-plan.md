# Refactor plan: drop the `eval` path, add a test harness

Status: **implemented** (phases 1–4 landed together; this file is kept as the
rationale and the checklist for follow-up work).

Scope was the builder scripts only. No language change, no new runtime
dependencies, no change to the workflow, config or upstream-merge model.

## Why

`utils.sh` builds shell command strings by hand and runs them with `eval`. That
is the seam that produced the quoting bugs this repo has hit (patch names with
spaces, `app_args[dl_from]` subscripts, `.gitignore` snapshots), and it made the
renderer (`patch_apk`) impossible to test. There were also **zero tests**: the
only verification of any change was a live build that downloads ~200 MB and
patches three apps.

A full rewrite was considered and rejected: the 739-commit upstream history and
`sync-upstream.sh` are what keep this repo cheap to maintain, and a rewrite in
another language would turn every upstream fix into a manual port.

## Phase 1 — argv arrays instead of eval

| Site | Before | After |
|---|---|---|
| `patches_list_versions` | `cmd_base` string + two `eval` variants | `local -a cmd=(...)`, run `"${cmd[@]}"`, rebuild for the legacy flag form |
| `patches_list` | string + `eval` fallback | same argv form |
| `patch_apk` | quoted command string + `eval` | fixed argv array plus the patcher args as separate elements |
| `build_rv` | `eval "declare -A args=${1#*=}"` | nameref plus an explicit copy, so the function's `args[..._dlurl]=""` mutation stays local |

Supporting changes:

- `add_patch_args` replaces `join_args`: it emits one `-d`/`-e` + name pair per
  patch, so a name containing spaces stays a single argv element.
- `split_args` tokenises `patcher-args`, honouring single/double quotes and
  backslash escapes — the one place a user string still needs shell-like
  parsing.
- microg de-duplication now scans the argv for an `-e`/`-i` pair instead of
  rewriting the joined string.
- The dead `branding_patch` block (computed, cleared, never used) is gone.
- `show_argv` logs a command with the keystore passwords masked; the previous
  `pr "$cmd"` printed them verbatim into the workflow log.

## Phase 2 — tests (`tests/run.sh`)

Pure bash, no dependencies, no network: `KS_ENV_FILE=/dev/null`, `gh_req`
stubbed to a fixture, each `config_update` case run in its own temp dir with
its own `build.md`/`failed_prev`.

Covered: change detection (matching patches, new patches, disabled app, retry
marker, siblings skipped), `get_highest_ver`, `split_args` (quoted names,
escaped quotes, plain flags), `add_patch_args` pairing, and `show_argv` masking.

Not covered on purpose: anything needing the CLI, JDK, a patch bundle or
Lavalink — the build workflow is the acceptance test for those.

## Phase 3 — CI

`.github/workflows/tests.yml` runs `bash tests/run.sh` and
`shellcheck -S warning` on every push to `main`, every PR and on demand.
The build pipeline is untouched.

## Phase 4 — docs

`CONFIG.md` documents the `patcher-args` tokenisation rule; `README.md` links
the test command.

## Verification

- `bash -n` + `shellcheck -S warning` + `bash tests/run.sh` (14 assertions).
- One manual `build.yml` dispatch: the logged patcher command must carry the
  same argument list as before (quotes aside), and
  `music-morphe-v9.30.53-arm64-v8a.apk` must build and verify with `apksigner`.

## Follow-ups not done here

- `patches_list_versions`/`patches_list` still shell out to `java` directly
  rather than through a wrapper, so they remain untestable in isolation.
- The workflow still owns release numbering and the `failed_prev` marker; a
  later pass could move that bookkeeping into a tested script.
