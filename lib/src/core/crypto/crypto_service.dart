import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encrypted_payload.dart';

// ---------------------------------------------------------------------------
// Pure-Dart X25519 + XSalsa20-Poly1305 implementation
// ---------------------------------------------------------------------------
// This avoids native FFI dependencies (flutter_sodium) that cause build
// issues on some platforms. The implementation uses:
//   - X25519 Diffie-Hellman for key agreement
//   - XSalsa20-Poly1305 for authenticated encryption
//
// For production, consider replacing with flutter_sodium FFI bindings for
// hardware-accelerated performance. The API surface remains identical.
// ---------------------------------------------------------------------------

/// Manages X25519 keypairs and encrypts/decrypts coordinate payloads.
///
/// Keys are persisted in SharedPreferences (base64-encoded). For production
/// deployments, migrate to `flutter_secure_storage` for hardware-backed
/// keystore protection.
class CryptoService {
  static const _privateKeyPref = 'ss_x25519_private_key';
  static const _publicKeyPref = 'ss_x25519_public_key';

  Uint8List? _privateKey;
  Uint8List? _publicKey;

  /// The user's X25519 public key, available after [initialize].
  Uint8List? get publicKey => _publicKey;

  /// Initializes the service, loading or generating a keypair.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPrivate = prefs.getString(_privateKeyPref);
    final storedPublic = prefs.getString(_publicKeyPref);

    if (storedPrivate != null && storedPublic != null) {
      _privateKey = base64Decode(storedPrivate);
      _publicKey = base64Decode(storedPublic);
      debugPrint('CryptoService: loaded existing keypair');
    } else {
      await _generateAndStoreKeypair(prefs);
      debugPrint('CryptoService: generated new X25519 keypair');
    }
  }

  Future<void> _generateAndStoreKeypair(SharedPreferences prefs) async {
    final seed = _secureRandomBytes(32);
    _privateKey = _clampPrivateKey(seed);
    _publicKey = _x25519ScalarMultBase(_privateKey!);

    await prefs.setString(_privateKeyPref, base64Encode(_privateKey!));
    await prefs.setString(_publicKeyPref, base64Encode(_publicKey!));
  }

  /// Derives a shared secret from our private key and a guardian's public key.
  Uint8List deriveSharedSecret(Uint8List guardianPublicKey) {
    if (_privateKey == null) {
      throw StateError('CryptoService not initialized. Call initialize() first.');
    }
    return _x25519ScalarMult(_privateKey!, guardianPublicKey);
  }

  /// Encrypts latitude, longitude, and timestamp into an [EncryptedPayload].
  EncryptedPayload encryptCoordinates({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required Uint8List sharedSecret,
  }) {
    final plaintext = utf8.encode(
      '$latitude|$longitude|${timestamp.millisecondsSinceEpoch}',
    );
    final nonce = _secureRandomBytes(24);
    final ciphertext = _xsalsa20Poly1305Encrypt(
      Uint8List.fromList(plaintext),
      nonce,
      sharedSecret,
    );
    return EncryptedPayload(nonce: nonce, ciphertext: ciphertext);
  }

  /// Decrypts an [EncryptedPayload] back into coordinates and timestamp.
  ({double latitude, double longitude, DateTime timestamp})
      decryptCoordinates({
    required EncryptedPayload payload,
    required Uint8List sharedSecret,
  }) {
    final plaintext = _xsalsa20Poly1305Decrypt(
      payload.ciphertext,
      payload.nonce,
      sharedSecret,
    );
    if (plaintext == null) {
      throw StateError('Decryption failed: authentication tag mismatch');
    }
    final parts = utf8.decode(plaintext).split('|');
    if (parts.length != 3) {
      throw FormatException('Invalid decrypted payload format');
    }
    return (
      latitude: double.parse(parts[0]),
      longitude: double.parse(parts[1]),
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2])),
    );
  }

  // ===========================================================================
  // Pure-Dart Cryptographic Primitives
  // ===========================================================================

  static Uint8List _secureRandomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }

  static Uint8List _clampPrivateKey(Uint8List key) {
    final clamped = Uint8List.fromList(key);
    clamped[0] &= 248;
    clamped[31] &= 127;
    clamped[31] |= 64;
    return clamped;
  }

  // ---------------------------------------------------------------------------
  // X25519 scalar multiplication (Montgomery ladder)
  // ---------------------------------------------------------------------------
  // Operates on the Montgomery curve Curve25519 over GF(2^255 - 19).

  static final BigInt _p =
      BigInt.two.pow(255) - BigInt.from(19);
  static final BigInt _a24 = BigInt.from(121665);

  static BigInt _modInverse(BigInt a, BigInt p) => a.modPow(p - BigInt.two, p);

  static Uint8List _x25519ScalarMult(Uint8List scalar, Uint8List point) {
    var u = _decodeUCoordinate(point);
    var x1 = u;
    var x2 = BigInt.one;
    var z2 = BigInt.zero;
    var x3 = u;
    var z3 = BigInt.one;
    var swap = 0;

    for (var t = 254; t >= 0; t--) {
      final kT = (scalar[t >> 3] >> (t & 7)) & 1;
      swap ^= kT;
      _cswap(swap, x2, x3);
      _cswap(swap, z2, z3);
      // After cswap, we need to use the returned values
      final cs1 = _cswapResult(swap, x2, x3);
      x2 = cs1.$1;
      x3 = cs1.$2;
      final cs2 = _cswapResult(swap, z2, z3);
      z2 = cs2.$1;
      z3 = cs2.$2;
      swap = kT;

      final a = (x2 + z2) % _p;
      final aa = (a * a) % _p;
      final b = (x2 - z2 + _p) % _p;
      final bb = (b * b) % _p;
      final e = (aa - bb + _p) % _p;
      final c = (x3 + z3) % _p;
      final d = (x3 - z3 + _p) % _p;
      final da = (d * a) % _p;
      final cb = (c * b) % _p;
      x3 = ((da + cb) % _p).modPow(BigInt.two, _p);
      z3 = (x1 * ((da - cb + _p) % _p).modPow(BigInt.two, _p)) % _p;
      x2 = (aa * bb) % _p;
      z2 = (e * (aa + _a24 * e % _p)) % _p;
    }

    final cs1 = _cswapResult(swap, x2, x3);
    x2 = cs1.$1;
    x3 = cs1.$2;
    final cs2 = _cswapResult(swap, z2, z3);
    z2 = cs2.$1;
    z3 = cs2.$2;

    final result = (x2 * _modInverse(z2, _p)) % _p;
    return _encodeUCoordinate(result);
  }

  static Uint8List _x25519ScalarMultBase(Uint8List scalar) {
    final basePoint = Uint8List(32);
    basePoint[0] = 9; // Curve25519 base point
    return _x25519ScalarMult(scalar, basePoint);
  }

  static void _cswap(int swap, BigInt a, BigInt b) {
    // No-op placeholder; actual swap handled by _cswapResult
  }

  static (BigInt, BigInt) _cswapResult(int swap, BigInt a, BigInt b) {
    if (swap != 0) return (b, a);
    return (a, b);
  }

  static BigInt _decodeUCoordinate(Uint8List u) {
    final clamped = Uint8List.fromList(u);
    clamped[31] &= 0x7f;
    var result = BigInt.zero;
    for (var i = 0; i < 32; i++) {
      result += BigInt.from(clamped[i]) << (8 * i);
    }
    return result % _p;
  }

  static Uint8List _encodeUCoordinate(BigInt u) {
    final result = Uint8List(32);
    var val = u % _p;
    for (var i = 0; i < 32; i++) {
      result[i] = (val & BigInt.from(0xff)).toInt();
      val >>= 8;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // XSalsa20-Poly1305 Authenticated Encryption
  // ---------------------------------------------------------------------------
  // Simplified implementation using HSalsa20 for subkey derivation,
  // Salsa20 for stream cipher, and Poly1305 for authentication.

  static Uint8List _xsalsa20Poly1305Encrypt(
    Uint8List plaintext,
    Uint8List nonce, // 24 bytes
    Uint8List key, // 32 bytes
  ) {
    // Derive subkey using HSalsa20 with first 16 bytes of nonce
    final subKey = _hsalsa20(key, nonce.sublist(0, 16));
    // Use last 8 bytes of nonce + 8 zero bytes as the Salsa20 nonce
    final subNonce = Uint8List(8);
    subNonce.setAll(0, nonce.sublist(16, 24));

    // Generate keystream
    final keystreamLen = plaintext.length + 32; // extra 32 for Poly1305 key
    final keystream = _salsa20Keystream(subKey, subNonce, keystreamLen);

    // First 32 bytes of keystream are the Poly1305 one-time key
    final poly1305Key = keystream.sublist(0, 32);

    // Encrypt plaintext
    final ciphertext = Uint8List(plaintext.length);
    for (var i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keystream[32 + i];
    }

    // Compute Poly1305 MAC over ciphertext
    final mac = _poly1305(ciphertext, Uint8List.fromList(poly1305Key));

    // Output: [mac (16 bytes) || ciphertext]
    final output = Uint8List(16 + ciphertext.length);
    output.setAll(0, mac);
    output.setAll(16, ciphertext);
    return output;
  }

  static Uint8List? _xsalsa20Poly1305Decrypt(
    Uint8List combined,
    Uint8List nonce,
    Uint8List key,
  ) {
    if (combined.length < 16) return null;

    final mac = combined.sublist(0, 16);
    final ciphertext = combined.sublist(16);

    final subKey = _hsalsa20(key, nonce.sublist(0, 16));
    final subNonce = Uint8List(8);
    subNonce.setAll(0, nonce.sublist(16, 24));

    final keystreamLen = ciphertext.length + 32;
    final keystream = _salsa20Keystream(subKey, subNonce, keystreamLen);
    final poly1305Key = keystream.sublist(0, 32);

    // Verify MAC
    final computedMac = _poly1305(ciphertext, Uint8List.fromList(poly1305Key));
    if (!_constantTimeEquals(mac, computedMac)) return null;

    // Decrypt
    final plaintext = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ keystream[32 + i];
    }
    return plaintext;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // Salsa20 quarter-round
  static int _rotl32(int v, int c) =>
      ((v << c) | (v >>> (32 - c))) & 0xFFFFFFFF;

  static List<int> _salsa20Core(List<int> input) {
    final x = List<int>.from(input);
    for (var i = 0; i < 10; i++) {
      // Column round
      x[4] ^= _rotl32((x[0] + x[12]) & 0xFFFFFFFF, 7);
      x[8] ^= _rotl32((x[4] + x[0]) & 0xFFFFFFFF, 9);
      x[12] ^= _rotl32((x[8] + x[4]) & 0xFFFFFFFF, 13);
      x[0] ^= _rotl32((x[12] + x[8]) & 0xFFFFFFFF, 18);
      x[9] ^= _rotl32((x[5] + x[1]) & 0xFFFFFFFF, 7);
      x[13] ^= _rotl32((x[9] + x[5]) & 0xFFFFFFFF, 9);
      x[1] ^= _rotl32((x[13] + x[9]) & 0xFFFFFFFF, 13);
      x[5] ^= _rotl32((x[1] + x[13]) & 0xFFFFFFFF, 18);
      x[14] ^= _rotl32((x[10] + x[6]) & 0xFFFFFFFF, 7);
      x[2] ^= _rotl32((x[14] + x[10]) & 0xFFFFFFFF, 9);
      x[6] ^= _rotl32((x[2] + x[14]) & 0xFFFFFFFF, 13);
      x[10] ^= _rotl32((x[6] + x[2]) & 0xFFFFFFFF, 18);
      x[3] ^= _rotl32((x[15] + x[11]) & 0xFFFFFFFF, 7);
      x[7] ^= _rotl32((x[3] + x[15]) & 0xFFFFFFFF, 9);
      x[11] ^= _rotl32((x[7] + x[3]) & 0xFFFFFFFF, 13);
      x[15] ^= _rotl32((x[11] + x[7]) & 0xFFFFFFFF, 18);
      // Row round
      x[1] ^= _rotl32((x[0] + x[3]) & 0xFFFFFFFF, 7);
      x[2] ^= _rotl32((x[1] + x[0]) & 0xFFFFFFFF, 9);
      x[3] ^= _rotl32((x[2] + x[1]) & 0xFFFFFFFF, 13);
      x[0] ^= _rotl32((x[3] + x[2]) & 0xFFFFFFFF, 18);
      x[6] ^= _rotl32((x[5] + x[4]) & 0xFFFFFFFF, 7);
      x[7] ^= _rotl32((x[6] + x[5]) & 0xFFFFFFFF, 9);
      x[4] ^= _rotl32((x[7] + x[6]) & 0xFFFFFFFF, 13);
      x[5] ^= _rotl32((x[4] + x[7]) & 0xFFFFFFFF, 18);
      x[11] ^= _rotl32((x[10] + x[9]) & 0xFFFFFFFF, 7);
      x[8] ^= _rotl32((x[11] + x[10]) & 0xFFFFFFFF, 9);
      x[9] ^= _rotl32((x[8] + x[11]) & 0xFFFFFFFF, 13);
      x[10] ^= _rotl32((x[9] + x[8]) & 0xFFFFFFFF, 18);
      x[12] ^= _rotl32((x[15] + x[14]) & 0xFFFFFFFF, 7);
      x[13] ^= _rotl32((x[12] + x[15]) & 0xFFFFFFFF, 9);
      x[14] ^= _rotl32((x[13] + x[12]) & 0xFFFFFFFF, 13);
      x[15] ^= _rotl32((x[14] + x[13]) & 0xFFFFFFFF, 18);
    }
    for (var i = 0; i < 16; i++) {
      x[i] = (x[i] + input[i]) & 0xFFFFFFFF;
    }
    return x;
  }

  static int _load32Le(Uint8List src, int offset) =>
      src[offset] |
      (src[offset + 1] << 8) |
      (src[offset + 2] << 16) |
      (src[offset + 3] << 24);

  static void _store32Le(Uint8List dst, int offset, int value) {
    dst[offset] = value & 0xff;
    dst[offset + 1] = (value >> 8) & 0xff;
    dst[offset + 2] = (value >> 16) & 0xff;
    dst[offset + 3] = (value >> 24) & 0xff;
  }

  static Uint8List _hsalsa20(Uint8List key, Uint8List nonce) {
    final sigma = utf8.encode('expand 32-byte k');
    final input = <int>[
      _load32Le(Uint8List.fromList(sigma), 0),
      _load32Le(key, 0),
      _load32Le(key, 4),
      _load32Le(key, 8),
      _load32Le(key, 12),
      _load32Le(Uint8List.fromList(sigma), 4),
      _load32Le(nonce, 0),
      _load32Le(nonce, 4),
      _load32Le(nonce, 8),
      _load32Le(nonce, 12),
      _load32Le(Uint8List.fromList(sigma), 8),
      _load32Le(key, 16),
      _load32Le(key, 20),
      _load32Le(key, 24),
      _load32Le(key, 28),
      _load32Le(Uint8List.fromList(sigma), 12),
    ];
    final x = List<int>.from(input);
    for (var i = 0; i < 10; i++) {
      // Column round
      x[4] ^= _rotl32((x[0] + x[12]) & 0xFFFFFFFF, 7);
      x[8] ^= _rotl32((x[4] + x[0]) & 0xFFFFFFFF, 9);
      x[12] ^= _rotl32((x[8] + x[4]) & 0xFFFFFFFF, 13);
      x[0] ^= _rotl32((x[12] + x[8]) & 0xFFFFFFFF, 18);
      x[9] ^= _rotl32((x[5] + x[1]) & 0xFFFFFFFF, 7);
      x[13] ^= _rotl32((x[9] + x[5]) & 0xFFFFFFFF, 9);
      x[1] ^= _rotl32((x[13] + x[9]) & 0xFFFFFFFF, 13);
      x[5] ^= _rotl32((x[1] + x[13]) & 0xFFFFFFFF, 18);
      x[14] ^= _rotl32((x[10] + x[6]) & 0xFFFFFFFF, 7);
      x[2] ^= _rotl32((x[14] + x[10]) & 0xFFFFFFFF, 9);
      x[6] ^= _rotl32((x[2] + x[14]) & 0xFFFFFFFF, 13);
      x[10] ^= _rotl32((x[6] + x[2]) & 0xFFFFFFFF, 18);
      x[3] ^= _rotl32((x[15] + x[11]) & 0xFFFFFFFF, 7);
      x[7] ^= _rotl32((x[3] + x[15]) & 0xFFFFFFFF, 9);
      x[11] ^= _rotl32((x[7] + x[3]) & 0xFFFFFFFF, 13);
      x[15] ^= _rotl32((x[11] + x[7]) & 0xFFFFFFFF, 18);
      // Row round
      x[1] ^= _rotl32((x[0] + x[3]) & 0xFFFFFFFF, 7);
      x[2] ^= _rotl32((x[1] + x[0]) & 0xFFFFFFFF, 9);
      x[3] ^= _rotl32((x[2] + x[1]) & 0xFFFFFFFF, 13);
      x[0] ^= _rotl32((x[3] + x[2]) & 0xFFFFFFFF, 18);
      x[6] ^= _rotl32((x[5] + x[4]) & 0xFFFFFFFF, 7);
      x[7] ^= _rotl32((x[6] + x[5]) & 0xFFFFFFFF, 9);
      x[4] ^= _rotl32((x[7] + x[6]) & 0xFFFFFFFF, 13);
      x[5] ^= _rotl32((x[4] + x[7]) & 0xFFFFFFFF, 18);
      x[11] ^= _rotl32((x[10] + x[9]) & 0xFFFFFFFF, 7);
      x[8] ^= _rotl32((x[11] + x[10]) & 0xFFFFFFFF, 9);
      x[9] ^= _rotl32((x[8] + x[11]) & 0xFFFFFFFF, 13);
      x[10] ^= _rotl32((x[9] + x[8]) & 0xFFFFFFFF, 18);
      x[12] ^= _rotl32((x[15] + x[14]) & 0xFFFFFFFF, 7);
      x[13] ^= _rotl32((x[12] + x[15]) & 0xFFFFFFFF, 9);
      x[14] ^= _rotl32((x[13] + x[12]) & 0xFFFFFFFF, 13);
      x[15] ^= _rotl32((x[14] + x[13]) & 0xFFFFFFFF, 18);
    }
    final out = Uint8List(32);
    _store32Le(out, 0, x[0]);
    _store32Le(out, 4, x[5]);
    _store32Le(out, 8, x[10]);
    _store32Le(out, 12, x[15]);
    _store32Le(out, 16, x[6]);
    _store32Le(out, 20, x[7]);
    _store32Le(out, 24, x[8]);
    _store32Le(out, 28, x[9]);
    return out;
  }

  static Uint8List _salsa20Keystream(
    Uint8List key,
    Uint8List nonce, // 8 bytes
    int length,
  ) {
    final sigma = utf8.encode('expand 32-byte k');
    final output = Uint8List(length);
    var offset = 0;
    var counter = 0;

    while (offset < length) {
      final input = <int>[
        _load32Le(Uint8List.fromList(sigma), 0),
        _load32Le(key, 0),
        _load32Le(key, 4),
        _load32Le(key, 8),
        _load32Le(key, 12),
        _load32Le(Uint8List.fromList(sigma), 4),
        _load32Le(nonce, 0),
        _load32Le(nonce, 4),
        counter & 0xFFFFFFFF,
        (counter >> 32) & 0xFFFFFFFF,
        _load32Le(Uint8List.fromList(sigma), 8),
        _load32Le(key, 16),
        _load32Le(key, 20),
        _load32Le(key, 24),
        _load32Le(key, 28),
        _load32Le(Uint8List.fromList(sigma), 12),
      ];

      final block = _salsa20Core(input);
      for (var i = 0; i < 16 && offset < length; i++) {
        final word = block[i];
        for (var j = 0; j < 4 && offset < length; j++) {
          output[offset++] = (word >> (j * 8)) & 0xff;
        }
      }
      counter++;
    }
    return output;
  }

  // ---------------------------------------------------------------------------
  // Poly1305 MAC (simplified)
  // ---------------------------------------------------------------------------
  static Uint8List _poly1305(Uint8List message, Uint8List key) {
    // Clamp r
    var r = BigInt.zero;
    for (var i = 0; i < 16; i++) {
      r += BigInt.from(key[i]) << (8 * i);
    }
    r &= BigInt.parse('0ffffffc0ffffffc0ffffffc0fffffff', radix: 16);

    var s = BigInt.zero;
    for (var i = 0; i < 16; i++) {
      s += BigInt.from(key[16 + i]) << (8 * i);
    }

    final p = (BigInt.one << 130) - BigInt.from(5);
    var accumulator = BigInt.zero;

    for (var i = 0; i < message.length; i += 16) {
      final blockEnd =
          (i + 16 > message.length) ? message.length : i + 16;
      var n = BigInt.zero;
      for (var j = i; j < blockEnd; j++) {
        n += BigInt.from(message[j]) << (8 * (j - i));
      }
      n += BigInt.one << (8 * (blockEnd - i));
      accumulator = ((accumulator + n) * r) % p;
    }

    accumulator = (accumulator + s) % (BigInt.one << 128);

    final mac = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      mac[i] = ((accumulator >> (8 * i)) & BigInt.from(0xff)).toInt();
    }
    return mac;
  }
}
