/*
 * Public demo/calculation entry points for the UI test panel (called from the
 * module root package's JSModule bridges in index.cj). Reuses the package-
 * internal hex()/unhex() helpers and the official ISO 18013-5 Annex D vector.
 */
package ohos_app_cangjie_eudi_cjcbor.cbor

import std.collection.ArrayList

/* {"hello": [1, 2, 3]} -> canonical CBOR, as hex. */
public func demoEncodeHex(): String {
    let items = ArrayList<CborValue>()
    items.add(cborInt(1))
    items.add(cborInt(2))
    items.add(cborInt(3))
    let pairs = ArrayList<(CborValue, CborValue)>()
    pairs.add((TextStringVal("hello"), ArrayVal(items)))
    let bytes = MapVal(pairs).encode()
    return "{\"hello\":[1,2,3]} -> ${bytes.size} bytes: ${hex(bytes)}"
}

/* Encode -> decode -> structural equality. */
public func demoRoundtrip(): String {
    let items = ArrayList<CborValue>()
    items.add(cborInt(1))
    items.add(cborInt(2))
    items.add(cborInt(3))
    let pairs = ArrayList<(CborValue, CborValue)>()
    pairs.add((TextStringVal("hello"), ArrayVal(items)))
    let value = MapVal(pairs)
    let bytes = value.encode()
    let ok = decodeCbor(bytes) == value
    return "round-trip: ${bytes.size} bytes, ok=${ok}"
}

/*
 * Canonical ordering demo: keys {10, 256, -1} inserted out of order must come
 * out bytewise-lexicographic (10, 256, -1) like SwiftCBOR / RFC 8949 §4.2.1 —
 * NOT length-first (10, -1, 256).
 */
public func demoCanonicalOrder(): String {
    let pairs = ArrayList<(CborValue, CborValue)>()
    pairs.add((cborInt(-1), cborInt(2)))
    pairs.add((cborInt(256), cborInt(1)))
    pairs.add((cborInt(10), cborInt(0)))
    let out = hex(MapVal(pairs).encode())
    let ok = out == "a30a00190100012002"
    return "canonical {10,256,-1}: ${out} (matches SwiftCBOR=${ok})"
}

/* Official ISO 18013-5 Annex D DeviceEngagement: decode -> re-encode byte identity. */
public func demoIsoVector(): String {
    let bytes = unhex(ANNEX_D_DEVICE_ENGAGEMENT)
    let ok = hex(decodeCbor(bytes).encode()) == ANNEX_D_DEVICE_ENGAGEMENT
    return "ISO 18013-5 DeviceEngagement (${bytes.size} bytes): re-encode identical=${ok}"
}

/* Decode arbitrary CBOR hex into a readable tree. */
public func demoDecodeHex(input: String): String {
    let cleaned = input.trimAscii()
    if (cleaned.size == 0 || cleaned.size % 2 != 0) {
        return "invalid hex: length must be even and non-empty"
    }
    try {
        return describe(decodeCbor(unhex(cleaned)))
    } catch (e: Exception) {
        return "decode error: ${e.toString()}"
    }
}

func describe(v: CborValue): String {
    match (v) {
        case UInt64Val(n) => return "uint(${n})"
        case NInt64Val(n) => return "int(-${n + 1})"
        case ByteStringVal(b) => return "bytes(${b.size}): ${hex(b)}"
        case TextStringVal(s) => return "text(\"${s}\")"
        case ArrayVal(items) =>
            var out = "array["
            var first = true
            for (it in items) {
                if (!first) {
                    out = out + ", "
                }
                out = out + describe(it)
                first = false
            }
            return out + "]"
        case MapVal(pairs) =>
            var out = "map{"
            var first = true
            for ((k, val) in pairs) {
                if (!first) {
                    out = out + ", "
                }
                out = out + describe(k) + ": " + describe(val)
                first = false
            }
            return out + "}"
        case TaggedVal(t, inner) => return "tag(${t}, ${describe(inner)})"
        case SimpleVal(n) => return "simple(${n})"
        case BoolVal(b) => return "bool(${b})"
        case NullVal => return "null"
        case UndefinedVal => return "undefined"
        case HalfVal(f) => return "half(${f})"
        case FloatVal(f) => return "float(${f})"
        case DoubleVal(d) => return "double(${d})"
        case BreakVal => return "break"
    }
}
