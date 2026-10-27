# eudi_cjcbor — EUDI Wallet CBOR module (Cangjie HAR)

CBOR module for the EUDI Wallet HarmonyOS/Cangjie migration (blueprint module id `cbor`),
packaged as a DevEco **Cangjie Static Library (HAR)**. It **wraps** the TPC library
[cbor4cj](https://gitcode.com/Cangjie-TPC/cbor4cj) — consumed as a **cjpm git dependency**
from the patched fork (branch `cjc_1.1.0` + build fixes: dead `std.reflect` imports removed,
`cjpm.toml` modernized for current DevEco SDK + combined declaration):
https://github.com/CJPLUK/cbor4cj — not absorbed into this repo at all.

## Layout

```
cjpm.toml                  HAR package ohos_app_cangjie_eudi_cjcbor
                           [dependencies] "cangjie_tpc::cbor4cj" = { git = <fork>, branch = "cjc_1.1.0" }
src/main/cangjie/
  index.cj                 HAR root package (template sayHello)
  cbor/                    package ohos_app_cangjie_eudi_cjcbor.cbor — OUR wrapper layer
    cbor_value.cj          CborValue facade (SwiftCBOR-shaped enum + encode/decode)
    cbor.cj                CborTag constants, tag-24 embedded-CBOR helpers, cborInt()
    demo.cj                demo calculations used by entry's UI test panel
    hex_util.cj / iso_vectors.cj   helpers + official ISO 18013-5 Annex D vectors
    *_test.cj              12 unit tests
```

## Division of labour vs cbor4cj

- **Decode**: fully delegated to cbor4cj's `CborDecoder`.
- **Leaf encode** (ints/strings/bytes/floats/simples): delegated to cbor4cj's encoders.
- **Container encode** (array/map/tag): implemented in the wrapper, deliberately. mDoc /
  SwiftCBOR require RFC 8949 §4.2.1 **bytewise-lexicographic** canonical map-key order;
  upstream `MapEncoder` sorts **length-first** (RFC 7049 §3.9), which diverges on key sets
  like `{10, 256, -1}` and would byte-mismatch signed mDoc/COSE structures from the iOS side.
  The wrapper therefore writes container heads itself and sorts map entries bytewise.
  Verified by `testCanonicalOrderingMatchesSwiftCBOR` and by byte-identical re-encode of the
  official ISO 18013-5 Annex D DeviceEngagement vector.
- The upstream `cjc_1.1.0` branch could not be consumed as-is: its dead `std.reflect`
  imports crash `cjc --scan-dependency` on current SDKs and its `[target]` sections point
  at an obsolete SDK layout. Those build-only fixes live in the fork (commit history there
  documents them); they are PR-able back to upstream.

## Public API (what downstream `mdoc` / `wallet-kit` consume)

`CborValue` enum (15 cases mirroring SwiftCBOR's `CBOR`) with `encode()/at()/field()/==`;
`decodeCbor` / `decodeCborAll`; `cborInt`; tag-24 `encodeEmbedded` / `decodeEmbedded`;
`CborTag` constants; `CborFacadeException`. Integer payloads ride a 64-bit channel
(Int64-range on decode; mDoc-sufficient).

## Build / test

- In DevEco: build normally (HAR + its cbor4cj dependency cross-compile via hvigor;
  `entry` consumes the HAR via oh-package + cjpm path dependency).
- Unit tests on host: copy `src/main/cangjie/cbor/` into a scratch cjpm package whose root
  package is named `ohos_app_cangjie_eudi_cjcbor` (stub root file) and which declares the same
  `"cangjie_tpc::cbor4cj"` git dependency, then `cjpm test` with the DevEco Cangjie SDK
  (`~/.cangjie-sdk/<ver>/cangjie/build-tools/envsetup.sh`). 12 cases, all passing (cjpm 1.1.3).
