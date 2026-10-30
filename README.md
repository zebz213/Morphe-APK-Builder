# Morphe APK Builder

[![CI](https://github.com/zebz213/Morphe-APK-Builder/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/zebz213/Morphe-APK-Builder/actions/workflows/ci.yml)

Builds **non-root** Morphe/ReVanced APKs for whatever is listed in [`config.toml`](./config.toml).
No Magisk or KernelSU module is produced — there is nothing to flash.

Get the [latest CI release](https://github.com/zebz213/Morphe-APK-Builder/releases).

<details><summary><big>Features</big></summary>
<ul>
 <li>Non-root APKs only, signed with this repo's own key</li>
 <li>Morphe patch sources (and other compatible forks), chosen per app</li>
 <li>Optional in-app update checks for APK builds</li>
 <li>Rebuilt daily with the latest app versions and patches</li>
</ul>
</details>

## Configure

- Apps, patch sources, brands and architecture live in [`config.toml`](./config.toml).
- Every option is documented in [`CONFIG.md`](./CONFIG.md).
- Generate one in the browser: **<https://zebz213.github.io/Morphe-APK-Builder/>** — toggle apps,
  patch lists and architecture, then copy or download the resulting `config.toml`.
  The same page lives at [`tools/config-gen/index.html`](./tools/config-gen/index.html) for
  offline use.

## Building

### On Termux
```console
bash <(curl -sSf https://raw.githubusercontent.com/zebz213/Morphe-APK-Builder/main/build-termux.sh)
```

### On Linux
```console
$ git clone --depth 1 https://github.com/zebz213/Morphe-APK-Builder morphe-apk-builder
$ cd morphe-apk-builder
$ ./build.sh
```

Finished APKs are written to `build/`.

## Signing

Builds are signed with a private key that is **not** in this repository. CI decodes it
from repository secrets (`KEYSTORE_P12_B64`, `KEYSTORE_BKS_B64`, `KEYSTORE_PASS`,
`KEYSTORE_ALIAS`) and fails the run if they are missing.

For a local build, create a gitignored `.env.keys` with `KS_FILE`, `KS_P12_FILE`,
`KS_ALIAS` and `KS_STORE_PASS`; it is sourced automatically (see the top of `utils.sh`).

APK updates must be signed with the same key as the installed app — builds signed with a
different key have to be installed after uninstalling the old one.
