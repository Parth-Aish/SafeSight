import 'dart:convert';
import 'dart:typed_data';

/// Represents an encrypted coordinate payload using XSalsa20-Poly1305.
///
/// The payload consists of a 24-byte nonce and variable-length ciphertext
/// containing encrypted (latitude, longitude, timestamp) data. The combined
/// format is: [nonce (24 bytes)][ciphertext (variable)].
class EncryptedPayload {
  /// 24-byte random nonce used for this encryption operation.
  final Uint8List nonce;

  /// Authenticated ciphertext produced by XSalsa20-Poly1305.
  final Uint8List ciphertext;

  const EncryptedPayload({
    required this.nonce,
    required this.ciphertext,
  });

  /// Serializes to a single base64 string: [nonce || ciphertext].
  String toBase64() {
    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setAll(0, nonce);
    combined.setAll(nonce.length, ciphertext);
    return base64Encode(combined);
  }

  /// Deserializes from a base64-encoded [nonce || ciphertext] string.
  factory EncryptedPayload.fromBase64(String encoded) {
    final combined = base64Decode(encoded);
    if (combined.length < 25) {
      throw FormatException(
        'Encrypted payload too short: ${combined.length} bytes (minimum 25)',
      );
    }
    return EncryptedPayload(
      nonce: Uint8List.fromList(combined.sublist(0, 24)),
      ciphertext: Uint8List.fromList(combined.sublist(24)),
    );
  }

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toMap() => {
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(ciphertext),
      };

  /// Constructs from a Firestore map.
  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedPayload(
      nonce: base64Decode(map['nonce'] as String),
      ciphertext: base64Decode(map['ciphertext'] as String),
    );
  }

  @override
  String toString() =>
      'EncryptedPayload(nonce: ${nonce.length}B, ciphertext: ${ciphertext.length}B)';
}
