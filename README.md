# EUDI Wallet — Cangjie CBOR project (DevEco)

DevEco Studio–openable HarmonyOS (Cangjie) project hosting the EUDI Wallet **CBOR module**
(blueprint module id `cbor`). Open this folder in DevEco (**File ▸ Open…**) and build/run `entry`.

## Layout

```
eudi_lib_cbor/                  ← project root (open THIS in DevEco)
├── build-profile.json5 …       project config; modules: entry, eudi_cjcbor
├── AppScope/ , hvigor/
├── entry/                      HAP — home page is the CBOR test panel (CangjieUI buttons
│                               calling the HAR's demo functions directly)
└── eudi_cjcbor/                ← CBOR module: DevEco Cangjie HAR (Static Library)
    ├── README.md               module docs: wrapper design, canonical ordering, tests
    └── src/main/cangjie/
        ├── index.cj            HAR root package
        └── cbor/               package ohos_app_cangjie_eudi_cjcbor.cbor — wrapper layer
```

## Architecture

- `eudi_cjcbor` is a **Cangjie HAR**; the CBOR engine is the TPC library
  [cbor4cj](https://gitcode.com/Cangjie-TPC/cbor4cj), consumed as a **cjpm git dependency**
  from the patched fork https://github.com/CJPLUK/cbor4cj (branch `cjc_1.1.0`;
  build-only fixes). Our code is only the wrapper layer (`…cbor` subpackage): SwiftCBOR-shaped `CborValue` facade, tag-24 helpers,
  and wrapper-side container encoding with RFC 8949 **bytewise** canonical map order
  (upstream sorts length-first — bypassed by the wrapper; see `eudi_cjcbor/README.md`).
- `entry` consumes the HAR via `oh-package.json5` (`"eudi_cjcbor": "file:../eudi_cjcbor"`)
  plus a cjpm path dependency in `entry/cjpm.toml`, so entry's **Cangjie** imports
  `ohos_app_cangjie_eudi_cjcbor.cbor.*` directly.
- Build chain verified by replaying hvigor's exact `CompileCangjie` environment
  (`cjpm build --target aarch64-linux-ohos`, SDK 6.1 / cjpm 1.1.3): HAR + entry both build;
  entry's output contains `libohos_app_cangjie_entry.so`, `libohos_app_cangjie_eudi_cjcbor.so`
  and `libcbor4cj@cangjie_tpc.so`.


## How to consume (downstream projects)

`ohpm` does not support git-URL dependencies, so consumers pull this repo at build time via a
small **hvigorfile.ts** hook (validated with DevEco's bundled node; idempotent, ~50ms when
already cloned). In the consuming project:

**1. Project-level `hvigorfile.ts`** — add above the export:

```ts
// --- auto-fetch git dependencies (runs at hvigor evaluation, before dependency resolution) ---
(function syncGitDeps() {
  /* eslint-disable @typescript-eslint/no-require-imports */
  const { execSync } = require('child_process');
  const fs = require('fs');
  const path = require('path');
  const DEPS = [{
    url: 'https://github.com/CJPLUK/eudi-lib-hmos-cbor.git',
    ref: '52ec047',                       // pin a commit (or tag) for reproducible builds
    dir: 'third_party/eudi_lib_cbor',
  }];
  for (const dep of DEPS) {
    const dst = path.resolve(__dirname, dep.dir);
    if (!fs.existsSync(path.join(dst, '.git'))) {
      fs.mkdirSync(path.dirname(dst), { recursive: true });
      execSync(`git clone --quiet "${dep.url}" "${dst}"`, { stdio: 'inherit' });
    }
    execSync(`git -C "${dst}" checkout --quiet ${dep.ref}`);
  }
})();
```

**2. `oh-package.json5`**:

```jsonc
"dependencies": { "eudi_cjcbor": "file:./third_party/eudi_lib_cbor/eudi_cjcbor" }
```

**3. `.gitignore`**: add `/third_party`.

**4. Cangjie-side import** (modules whose Cangjie code calls CBOR directly) — additionally in
that module's `cjpm.toml`:

```toml
[dependencies]
  ohos_app_cangjie_eudi_cjcbor = { path = "../third_party/eudi_lib_cbor/eudi_cjcbor" }
```

then `import ohos_app_cangjie_eudi_cjcbor.cbor.*`.

Alternative: `git submodule add` this repo and use the same `file:` reference.

## Tests

12 unit tests (RFC vectors, SwiftCBOR-order regression `{10,256,-1}`, tag-24, official
ISO 18013-5 Annex D vectors incl. byte-identical DeviceEngagement re-encode) live beside the
wrapper in `eudi_cjcbor/src/main/cangjie/cbor/`. All 12 pass on cjpm 1.1.3 — host run recipe
in `eudi_cjcbor/README.md`.
