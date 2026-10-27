/*
 * EUDI Wallet — CBOR subpackage of module eudi_cjcbor
 *
 * Well-known tag numbers, the tag-24 embedded-CBOR helpers that mDoc relies on
 * heavily (IssuerSignedItemBytes / DeviceNameSpacesBytes are #6.24(bstr)
 * wrappers), and small ergonomic constructors. These are the pieces SwiftCBOR
 * exposes that the raw cbor4cj engine lacked.
 */
package ohos_app_cangjie_eudi_cjcbor.cbor

public class CborFacadeException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/** Well-known CBOR tag numbers used across EUDI / mDoc (ISO 18013-5) / COSE. */
public class CborTag {
    public static let STANDARD_DATE_TIME: UInt64 = 0    // tdate / RFC 3339 string
    public static let EPOCH_DATE_TIME: UInt64 = 1       // epoch-based date/time
    public static let POSITIVE_BIGNUM: UInt64 = 2
    public static let NEGATIVE_BIGNUM: UInt64 = 3
    public static let COSE_MAC0: UInt64 = 17
    public static let COSE_SIGN1: UInt64 = 18
    public static let ENCODED_CBOR: UInt64 = 24         // #6.24(bstr) — embedded CBOR data item
    public static let URI: UInt64 = 32
    public static let COSE_SIGN: UInt64 = 98
    public static let FULL_DATE: UInt64 = 1004          // full-date string (ISO 18013-5)
}

/**
 * Build a CBOR integer, picking the unsigned/negative representation the way
 * SwiftCBOR's `CBOR(integerLiteral:)` does.
 */
public func cborInt(value: Int64): CborValue {
    if (value < 0) {
        // n such that value == -1 - n  →  n = -1 - value
        return NInt64Val(UInt64(-1 - value))
    }
    return UInt64Val(UInt64(value))
}

/**
 * Wrap a value as a tag-24 embedded CBOR data item: #6.24(bstr .cbor inner).
 * This is the mDoc "...Bytes" pattern (e.g. IssuerSignedItemBytes).
 */
public func encodeEmbedded(value: CborValue): CborValue {
    return TaggedVal(CborTag.ENCODED_CBOR, ByteStringVal(value.encode()))
}

/** Reverse of `encodeEmbedded`: unwrap a tag-24 embedded CBOR value. */
public func decodeEmbedded(value: CborValue): CborValue {
    match (value) {
        case TaggedVal(t, inner) =>
            if (t != CborTag.ENCODED_CBOR) {
                throw CborFacadeException("expected tag 24, got tag " + t.toString())
            }
            match (inner) {
                case ByteStringVal(b) => return decodeCbor(b)
                case _ => throw CborFacadeException("tag 24 payload is not a byte string")
            }
        case _ => throw CborFacadeException("value is not a tag-24 embedded CBOR item")
    }
}
