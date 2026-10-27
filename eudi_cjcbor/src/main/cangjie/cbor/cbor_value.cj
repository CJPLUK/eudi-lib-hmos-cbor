/*
 * EUDI Wallet — CBOR wrapper over the cbor4cj TPC library.
 *
 * `CborValue` is a value-type facade mirroring iOS SwiftCBOR's `CBOR` enum so
 * the EUDI mDoc / wallet-kit Swift sources translate mechanically. It DEPENDS
 * on cbor4cj (vendored verbatim under third_party/cbor4cj, package `cbor4cj`)
 * instead of absorbing its code:
 *
 *   - decoding is fully delegated to cbor4cj's CborDecoder;
 *   - leaf encoding (ints, strings, bytes, floats, simples) is delegated to
 *     cbor4cj's piecewise encoders;
 *   - container encoding (array / map / tag) is done HERE, because mDoc /
 *     SwiftCBOR require RFC 8949 §4.2.1 bytewise-lexicographic map-key order
 *     while cbor4cj's MapEncoder sorts length-first (RFC 7049 §3.9) — see
 *     third_party/cbor4cj/PATCHES.md "Known upstream issues".
 *
 *   SwiftCBOR.CBOR            CborValue (this package)
 *   --------------           -----------------------
 *   .unsignedInt(UInt64)     UInt64Val(UInt64)
 *   .negativeInt(UInt64)     NInt64Val(UInt64)      // value = -1 - n (CBOR convention)
 *   .byteString([UInt8])     ByteStringVal(Array<UInt8>)
 *   .utf8String(String)      TextStringVal(String)
 *   .array([CBOR])           ArrayVal(ArrayList<CborValue>)
 *   .map([CBOR:CBOR])        MapVal(ArrayList<(CborValue, CborValue)>)  // insertion order kept
 *   .tagged(Tag, CBOR)       TaggedVal(UInt64, CborValue)
 *   .simple(UInt8)           SimpleVal(UInt8)
 *   .boolean(Bool)           BoolVal(Bool)
 *   .null / .undefined       NullVal / UndefinedVal
 *   .half/.float/.double     HalfVal(Float32) / FloatVal(Float32) / DoubleVal(Float64)
 *   .break                   BreakVal
 *
 * encode() always produces deterministic/canonical CBOR. Integer payloads ride
 * a 64-bit channel; values outside Int64 range on decode are unsupported
 * (mDoc does not need them).
 */
package ohos_app_cangjie_eudi_cjcbor.cbor

import std.collection.ArrayList
import std.collection.LinkedList
import std.io.ByteBuffer
import std.math.numeric.BigInt
import cbor4cj.*

public enum CborValue {
    | UInt64Val(UInt64)
    | NInt64Val(UInt64)
    | ByteStringVal(Array<UInt8>)
    | TextStringVal(String)
    | ArrayVal(ArrayList<CborValue>)
    | MapVal(ArrayList<(CborValue, CborValue)>)
    | TaggedVal(UInt64, CborValue)
    | SimpleVal(UInt8)
    | BoolVal(Bool)
    | NullVal
    | UndefinedVal
    | HalfVal(Float32)
    | FloatVal(Float32)
    | DoubleVal(Float64)
    | BreakVal

    /** Encode this value to canonical CBOR bytes. */
    public func encode(): Array<UInt8> {
        let out = ArrayList<UInt8>()
        this.encodeInto(out)
        return out.toArray()
    }

    /*
     * Containers are encoded by this wrapper (canonical bytewise map order);
     * everything else is delegated to cbor4cj's encoders.
     */
    func encodeInto(out: ArrayList<UInt8>): Unit {
        match (this) {
            case ArrayVal(items) =>
                appendHead(out, 4, UInt64(items.size))
                for (it in items) {
                    it.encodeInto(out)
                }
            case MapVal(pairs) =>
                // RFC 8949 §4.2.1: order entries by the encoded key, bytewise
                // (matches SwiftCBOR's lexicographicallyPrecedes). cbor4cj's
                // MapEncoder is deliberately bypassed (it sorts length-first).
                let encoded = ArrayList<(Array<UInt8>, Array<UInt8>)>()
                for ((k, v) in pairs) {
                    encoded.add((k.encode(), v.encode()))
                }
                sortPairsByKeyBytes(encoded)
                appendHead(out, 5, UInt64(pairs.size))
                for ((kb, vb) in encoded) {
                    appendAll(out, kb)
                    appendAll(out, vb)
                }
            case TaggedVal(t, inner) =>
                appendHead(out, 6, t)
                inner.encodeInto(out)
            case _ =>
                appendAll(out, engineEncode(this.toLeafDataItem()))
        }
    }

    /** Map a non-container value onto the corresponding cbor4cj DataItem. */
    func toLeafDataItem(): DataItem {
        match (this) {
            case UInt64Val(v) => return UnsignedInteger(BigInt(v))
            case NInt64Val(n) => return NegativeInteger(BigInt(-1) - BigInt(n))
            case ByteStringVal(b) => return ByteString(b)
            case TextStringVal(s) => return UnicodeString(s)
            case SimpleVal(v) => return SimpleValue(Int32(v))
            case BoolVal(b) => return if (b) { SimpleValue.TRUE } else { SimpleValue.FALSE }
            case NullVal => return SimpleValue.NULL
            case UndefinedVal => return SimpleValue.UNDEFINED
            case HalfVal(f) => return HalfPrecisionFloat(f)
            case FloatVal(f) => return SinglePrecisionFloat(f)
            case DoubleVal(d) => return DoublePrecisionFloat(d)
            case BreakVal => return Special.BREAK
            case _ => throw CborFacadeException("container is not a leaf data item")
        }
    }

    /** Array element access (None if not an array / out of range). */
    public func at(index: Int64): ?CborValue {
        match (this) {
            case ArrayVal(items) =>
                if (index >= 0 && index < items.size) {
                    return items[index]
                }
                return None
            case _ => return None
        }
    }

    /** Map value lookup by key (None if not a map / key absent). */
    public func field(key: CborValue): ?CborValue {
        match (this) {
            case MapVal(pairs) =>
                for ((k, v) in pairs) {
                    if (k == key) {
                        return v
                    }
                }
                return None
            case _ => return None
        }
    }

    public operator func ==(rhs: CborValue): Bool {
        match ((this, rhs)) {
            case (UInt64Val(a), UInt64Val(b)) => return a == b
            case (NInt64Val(a), NInt64Val(b)) => return a == b
            case (ByteStringVal(a), ByteStringVal(b)) => return bytesEqual(a, b)
            case (TextStringVal(a), TextStringVal(b)) => return a == b
            case (ArrayVal(a), ArrayVal(b)) =>
                if (a.size != b.size) {
                    return false
                }
                var i = 0
                while (i < a.size) {
                    if (!(a[i] == b[i])) {
                        return false
                    }
                    i++
                }
                return true
            case (MapVal(a), MapVal(b)) =>
                if (a.size != b.size) {
                    return false
                }
                var i = 0
                while (i < a.size) {
                    if (!(a[i][0] == b[i][0]) || !(a[i][1] == b[i][1])) {
                        return false
                    }
                    i++
                }
                return true
            case (TaggedVal(ta, ia), TaggedVal(tb, ib)) => return ta == tb && ia == ib
            case (SimpleVal(a), SimpleVal(b)) => return a == b
            case (BoolVal(a), BoolVal(b)) => return a == b
            case (NullVal, NullVal) => return true
            case (UndefinedVal, UndefinedVal) => return true
            case (HalfVal(a), HalfVal(b)) => return a == b
            case (FloatVal(a), FloatVal(b)) => return a == b
            case (DoubleVal(a), DoubleVal(b)) => return a == b
            case (BreakVal, BreakVal) => return true
            case _ => return false
        }
    }

    public operator func !=(rhs: CborValue): Bool {
        return !(this == rhs)
    }
}

/* ---------- wrapper-side encoding primitives ---------- */

/** Shortest-form CBOR head: major type + length/value (RFC 8949 §3). */
func appendHead(out: ArrayList<UInt8>, major: UInt8, value: UInt64): Unit {
    let mb = major << 5
    if (value < 24) {
        out.add(mb | UInt8(value))
    } else if (value <= 0xFF) {
        out.add(mb | 24)
        out.add(UInt8(value))
    } else if (value <= 0xFFFF) {
        out.add(mb | 25)
        out.add(UInt8((value >> 8) & 0xFF))
        out.add(UInt8(value & 0xFF))
    } else if (value <= 0xFFFFFFFF) {
        out.add(mb | 26)
        out.add(UInt8((value >> 24) & 0xFF))
        out.add(UInt8((value >> 16) & 0xFF))
        out.add(UInt8((value >> 8) & 0xFF))
        out.add(UInt8(value & 0xFF))
    } else {
        out.add(mb | 27)
        out.add(UInt8((value >> 56) & 0xFF))
        out.add(UInt8((value >> 48) & 0xFF))
        out.add(UInt8((value >> 40) & 0xFF))
        out.add(UInt8((value >> 32) & 0xFF))
        out.add(UInt8((value >> 24) & 0xFF))
        out.add(UInt8((value >> 16) & 0xFF))
        out.add(UInt8((value >> 8) & 0xFF))
        out.add(UInt8(value & 0xFF))
    }
}

func appendAll(out: ArrayList<UInt8>, bytes: Array<UInt8>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

/** Encode one DataItem through cbor4cj. */
func engineEncode(item: DataItem): Array<UInt8> {
    let buf = ByteBuffer()
    CborEncoder(buf).encode(item)
    return buf.bytes()
}

/** -1 / 0 / 1, pure bytewise then shorter-first (lexicographicallyPrecedes). */
func compareBytes(a: Array<UInt8>, b: Array<UInt8>): Int64 {
    let minLen = if (a.size < b.size) {
        a.size
    } else {
        b.size
    }
    var i = 0
    while (i < minLen) {
        if (a[i] < b[i]) {
            return -1
        }
        if (a[i] > b[i]) {
            return 1
        }
        i++
    }
    if (a.size < b.size) {
        return -1
    }
    if (a.size > b.size) {
        return 1
    }
    return 0
}

/** In-place insertion sort by encoded key (map sizes are small in mDoc). */
func sortPairsByKeyBytes(pairs: ArrayList<(Array<UInt8>, Array<UInt8>)>): Unit {
    var i = 1
    while (i < pairs.size) {
        let cur = pairs[i]
        var j = i - 1
        while (j >= 0 && compareBytes(pairs[j][0], cur[0]) > 0) {
            pairs[j + 1] = pairs[j]
            j--
        }
        pairs[j + 1] = cur
        i++
    }
}

func bytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) {
        return false
    }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i++
    }
    return true
}

/** Convert a non-negative cbor4cj BigInt into UInt64 (Int64 range; mDoc-sufficient). */
func bigToUInt64(b: BigInt): UInt64 {
    return UInt64(b.toInt64())
}

/* ---------- decoding: fully delegated to cbor4cj ---------- */

/** Map a cbor4cj DataItem (possibly tag-bearing) back to a CborValue. */
func fromDataItem(item: DataItem): CborValue {
    if (item.hasTag()) {
        let t = item.getTag().getOrThrow().getValue()
        item.removeTag()
        return TaggedVal(UInt64(t), fromDataItem(item))
    }
    match (item.getMajorType().name) {
        case "UNSIGNED_INTEGER" =>
            return UInt64Val(bigToUInt64((item as UnsignedInteger).getOrThrow().getValue()))
        case "NEGATIVE_INTEGER" =>
            let actual = (item as NegativeInteger).getOrThrow().getValue()
            return NInt64Val(bigToUInt64(BigInt(-1) - actual))
        case "BYTE_STRING" =>
            let b = (item as ByteString).getOrThrow().getBytes()
            return ByteStringVal(b ?? Array<UInt8>())
        case "UNICODE_STRING" =>
            let s = (item as UnicodeString).getOrThrow().getString()
            return TextStringVal(s ?? "")
        case "ARRAY" =>
            let arr = (item as CborArray).getOrThrow()
            let out = ArrayList<CborValue>()
            for (e in arr.getDataItems()) {
                out.add(fromDataItem(e))
            }
            return ArrayVal(out)
        case "MAP" =>
            let m = (item as CborMap).getOrThrow()
            let out = ArrayList<(CborValue, CborValue)>()
            for (k in m.getKeys()) {
                out.add((fromDataItem(k), fromDataItem(m.get(k).getOrThrow())))
            }
            return MapVal(out)
        case "SPECIAL" => return fromSpecial(item)
        case _ => throw CborFacadeException("unsupported major type in decode: " + item.getMajorType().name)
    }
}

func fromSpecial(item: DataItem): CborValue {
    if (item is HalfPrecisionFloat) {
        return HalfVal((item as HalfPrecisionFloat).getOrThrow().getValue())
    }
    if (item is SinglePrecisionFloat) {
        return FloatVal((item as SinglePrecisionFloat).getOrThrow().getValue())
    }
    if (item is DoublePrecisionFloat) {
        return DoubleVal((item as DoublePrecisionFloat).getOrThrow().getValue())
    }
    if (item is SimpleValue) {
        let sv = (item as SimpleValue).getOrThrow()
        match (sv.getSimpleValueType().name) {
            case "TRUE" => return BoolVal(true)
            case "FALSE" => return BoolVal(false)
            case "NULL" => return NullVal
            case "UNDEFINED" => return UndefinedVal
            case _ => return SimpleVal(UInt8(sv.getValue()))
        }
    }
    return BreakVal
}

/** Decode the first top-level CBOR value from `bytes`. */
public func decodeCbor(bytes: Array<UInt8>): CborValue {
    let items = decodeCborAll(bytes)
    if (items.isEmpty()) {
        throw CborFacadeException("no CBOR data item in input")
    }
    return items[0]
}

/** Decode every top-level CBOR value in `bytes` (CBOR sequence). */
public func decodeCborAll(bytes: Array<UInt8>): ArrayList<CborValue> {
    let buf = ByteBuffer()
    buf.write(bytes)
    let dec = CborDecoder(buf)
    // Keep tags 30 (rational) and 38 (language-tagged) as plain TaggedVal rather
    // than letting cbor4cj fold them into bespoke types — more faithful and
    // mDoc never relies on that folding.
    dec.setAutoDecodeRationalNumbers(false)
    dec.setAutoDecodeLanguageTaggedStrings(false)
    let out = ArrayList<CborValue>()
    let items: LinkedList<DataItem> = dec.decode()
    for (di in items) {
        out.add(fromDataItem(di))
    }
    return out
}
