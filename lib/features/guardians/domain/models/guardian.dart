import 'dart:convert';
import 'dart:typed_data';

class Guardian {
  final String id;
  final String email;
  final String displayName;
  final bool isAccepted;

  /// X25519 public key for E2E encrypted location sharing.
  /// Null if the guardian hasn't set up encryption yet.
  final Uint8List? publicKey;

  const Guardian({
    required this.id,
    required this.email,
    this.displayName = '',
    this.isAccepted = false,
    this.publicKey,
  });

  Guardian copyWith({
    String? displayName,
    bool? isAccepted,
    Uint8List? publicKey,
  }) {
    return Guardian(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      isAccepted: isAccepted ?? this.isAccepted,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'isAccepted': isAccepted,
        if (publicKey != null) 'publicKey': base64Encode(publicKey!),
      };

  factory Guardian.fromMap(String id, Map<String, dynamic> map) {
    Uint8List? pubKey;
    final pubKeyStr = map['publicKey'] as String?;
    if (pubKeyStr != null && pubKeyStr.isNotEmpty) {
      try {
        pubKey = base64Decode(pubKeyStr);
      } catch (_) {}
    }

    return Guardian(
      id: id,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      isAccepted: map['isAccepted'] as bool? ?? false,
      publicKey: pubKey,
    );
  }
}

