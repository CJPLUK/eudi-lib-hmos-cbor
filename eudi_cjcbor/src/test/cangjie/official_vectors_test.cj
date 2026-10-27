/*
 * End-to-end conformance against the official ISO/IEC 18013-5 Annex D test
 * vectors (mirrored from the ISO mDL reference impl, openwallet-foundation/multipaz
 * TestVectors.kt). These exercise the full decode + canonical re-encode pipeline
 * on real mDoc CBOR: tag-24 embedded data, COSE structures, nested maps/arrays,
 * byte strings, booleans, integer keys.
 */
package ohos_app_cangjie_eudi_cjcbor_local_test

import ohos_app_cangjie_eudi_cjcbor.cbor.*
import std.unittest.*
import std.unittest.testmacro.*

// DeviceEngagement: fully canonical per ISO 18013-5 -> must re-encode byte-identical.
// SessionTermination = {"status": 20} -> trivially canonical.
// Full DeviceResponse (~3.5 KB). Top-level map is in semantic (non-canonical)
// key order, so this one is decode + stability, not byte-identity.

@Test
public class OfficialVectorTest {
    @TestCase
    func testDeviceEngagementByteIdentity() {
        let bytes = unhex(ANNEX_D_DEVICE_ENGAGEMENT)
        // decode the official canonical bytes and re-encode: must match exactly.
        @Assert(hex(decodeCbor(bytes).encode()), ANNEX_D_DEVICE_ENGAGEMENT)
    }

    @TestCase
    func testSessionTerminationByteIdentity() {
        let bytes = unhex(ANNEX_D_SESSION_TERMINATION)
        @Assert(hex(decodeCbor(bytes).encode()), ANNEX_D_SESSION_TERMINATION)
    }

    @TestCase
    func testDeviceResponseDecodeAndSpotCheck() {
        let resp = decodeCbor(unhex(ANNEX_D_DEVICE_RESPONSE))
        // Real mDoc DeviceResponse decodes; semantic fields are reachable
        // regardless of key order (proves decoder handles the full structure).
        @Assert(resp.field(TextStringVal("version")).getOrThrow() == TextStringVal("1.0"))
        @Assert(resp.field(TextStringVal("status")).getOrThrow() == cborInt(0))
        @Assert(resp.field(TextStringVal("documents")).isSome())
    }

    @TestCase
    func testDeviceResponseCanonicalisationIsStable() {
        // The envelope is in semantic (non-canonical) key order, so our canonical
        // re-encoding is a *fixpoint*: encode(decode(bytes)) must equal
        // encode(decode(that)) at the byte level. (Structural == is order-sensitive
        // by design, so we compare canonical bytes, not the order-preserving trees.)
        let e1 = decodeCbor(unhex(ANNEX_D_DEVICE_RESPONSE)).encode()
        let e2 = decodeCbor(e1).encode()
        @Assert(hex(e1), hex(e2))
    }
}
