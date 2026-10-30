# ReVanced APK builder

[![CI](https://github.com/zebz213/revanced-apk/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/zebz213/revanced-apk/actions/workflows/ci.yml)

Builds **non-root** ReVanced/Morphe APKs for whatever is listed in [`config.toml`](./config.toml).
No Magisk or KernelSU module is produced — there is nothing to flash.

Get the [latest CI release](https://github.com/zebz213/revanced-apk/releases).

<details><summary><big>Features</big></summary>
<ul>
 <li>Non-root APKs only, signed with this repo's own key</li>
 <li>ReVanced and Morphe patch sources, chosen per app</li>
 <li>Optional in-app update checks for APK builds</li>
 <li>Rebuilt daily with the latest app versions and patches</li>
</ul>
</details>

## Configure

- Apps, patch sources, brands and architecture live in [`config.toml`](./config.toml).
- Every option is documented in [`CONFIG.md`](./CONFIG.md).
- [`tools/config-gen/index.html`](./tools/config-gen/index.html) is a self-contained generator:
  open it in a browser, edit the apps, copy or download the resulting `config.toml`.

## Building

### On Termux
```console
bash <(curl -sSf https://raw.githubusercontent.com/zebz213/revanced-apk/main/build-termux.sh)
```

### On Linux
```console
$ git clone https://github.com/zebz213/revanced-apk --depth 1
$ cd revanced-apk
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
