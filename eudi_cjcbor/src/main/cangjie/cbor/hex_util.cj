/*
 * Hex helpers shared by the facade demos and the test files. Lives in a
 * non-test file because cjpm only compiles *_test.cj under `cjpm test`,
 * while demo.cj (production code) needs these too.
 */
package ohos_app_cangjie_eudi_cjcbor.cbor

public func hex(bytes: Array<UInt8>): String {
    let digits = "0123456789abcdef".toArray()
    let out = Array<UInt8>(bytes.size * 2, repeat: 0)
    var i = 0
    for (b in bytes) {
        out[i] = digits[Int64(b >> 4)]
        out[i + 1] = digits[Int64(b & 0x0F)]
        i += 2
    }
    return String.fromUtf8(out)
}

func nib(c: UInt8): UInt8 {
    if (c >= 48 && c <= 57) {
        return c - 48
    }
    if (c >= 97 && c <= 102) {
        return c - 97 + 10
    }
    if (c >= 65 && c <= 70) {
        return c - 65 + 10
    }
    return 0
}

public func unhex(s: String): Array<UInt8> {
    let a = s.toArray()
    let out = Array<UInt8>(a.size / 2, repeat: 0)
    var i = 0
    while (i < out.size) {
        out[i] = (nib(a[i * 2]) << 4) | nib(a[i * 2 + 1])
        i++
    }
    return out
}
