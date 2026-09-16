import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// BLE Beacon Service
// ---------------------------------------------------------------------------
// Broadcasts SOS payloads via BLE advertising when network connectivity
// drops. Nearby SafeSight users scanning for the UUID can relay the SOS.
//
// NOTE: flutter_reactive_ble does not support BLE peripheral advertising
// out of the box on all platforms. This implementation provides the
// interface and encoding layer; actual BLE advertising requires
// platform-specific integration (Android BLE Advertiser API,
// iOS CoreBluetooth peripheral mode).
//
// For now, this service stores beacon payloads and manages the logical
// state of BLE broadcast intent. The actual hardware integration is
// platform-channel ready.
// ---------------------------------------------------------------------------

/// SafeSight BLE namespace UUID.
const String safeSightBleUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

/// SOS payload broadcast via BLE.
class SosBeaconPayload {
  final String userIdHash; // SHA-256 hash of user UID
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String triggerReason;

  const SosBeaconPayload({
    required this.userIdHash,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.triggerReason,
  });

  /// Encodes the payload into a compact byte format for BLE advertising.
  ///
  /// Format: [userHash(8B)][lat(4B)][lng(4B)][timestamp(4B)][reason(2B)]
  /// Total: 22 bytes (fits in BLE advertisement data)
  Uint8List encode() {
    final buffer = ByteData(22);

    // First 8 bytes of user hash
    final hashBytes = utf8.encode(userIdHash);
    for (var i = 0; i < 8 && i < hashBytes.length; i++) {
      buffer.setUint8(i, hashBytes[i]);
    }

    // Lat/Lng as float32
    buffer.setFloat32(8, latitude, Endian.little);
    buffer.setFloat32(12, longitude, Endian.little);

    // Timestamp as epoch seconds (32-bit)
    buffer.setUint32(16, timestamp.millisecondsSinceEpoch ~/ 1000, Endian.little);

    // Trigger reason code (2 bytes)
    final reasonCode = _encodeReason(triggerReason);
    buffer.setUint16(20, reasonCode, Endian.little);

    return buffer.buffer.asUint8List();
  }

  /// Decodes a BLE payload back into an [SosBeaconPayload].
  factory SosBeaconPayload.decode(Uint8List data) {
    if (data.length < 22) {
      throw FormatException('BLE payload too short: ${data.length} bytes');
    }
    final buffer = ByteData.sublistView(data);

    return SosBeaconPayload(
      userIdHash: String.fromCharCodes(data.sublist(0, 8)),
      latitude: buffer.getFloat32(8, Endian.little),
      longitude: buffer.getFloat32(12, Endian.little),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        buffer.getUint32(16, Endian.little) * 1000,
      ),
      triggerReason: _decodeReason(buffer.getUint16(20, Endian.little)),
    );
  }

  static int _encodeReason(String reason) {
    switch (reason) {
      case 'Manual SOS':
        return 0x01;
      case 'Snatch/Impact Detected':
        return 0x02;
      case 'Distress Sound Detected':
        return 0x03;
      case 'Walk With Me Timeout':
        return 0x04;
      default:
        return 0xFF;
    }
  }

  static String _decodeReason(int code) {
    switch (code) {
      case 0x01:
        return 'Manual SOS';
      case 0x02:
        return 'Snatch/Impact Detected';
      case 0x03:
        return 'Distress Sound Detected';
      case 0x04:
        return 'Walk With Me Timeout';
      default:
        return 'Unknown Emergency';
    }
  }
}

/// Manages BLE SOS beacon broadcasting and scanning.
///
/// Activates when network connectivity drops and an SOS is active.
/// Deactivates when connectivity is restored.
class BleBeaconService {
  bool _isBroadcasting = false;
  SosBeaconPayload? _currentPayload;

  /// Whether the service is currently broadcasting.
  bool get isBroadcasting => _isBroadcasting;

  /// The current broadcast payload, if any.
  SosBeaconPayload? get currentPayload => _currentPayload;

  /// Start broadcasting an SOS beacon payload.
  ///
  /// In production, this would use platform channels to activate
  /// the BLE peripheral advertiser with SafeSight's UUID namespace.
  Future<void> startBroadcast(SosBeaconPayload payload) async {
    _currentPayload = payload;
    _isBroadcasting = true;

    final encoded = payload.encode();
    debugPrint(
      'BleBeacon: BROADCASTING ${encoded.length}B payload '
      '(${payload.triggerReason})',
    );

    // TODO: Activate platform-specific BLE peripheral advertising
    // Android: BluetoothLeAdvertiser.startAdvertising()
    // iOS: CBPeripheralManager.startAdvertising()
    // Beacon interval: 100ms for maximum discovery speed
  }

  /// Stop broadcasting.
  Future<void> stopBroadcast() async {
    _isBroadcasting = false;
    _currentPayload = null;
    debugPrint('BleBeacon: broadcast stopped');

    // TODO: Stop platform-specific BLE advertising
  }

  /// Scan for nearby SafeSight SOS beacons.
  ///
  /// Returns a stream of decoded beacon payloads from nearby devices.
  Stream<SosBeaconPayload> scanForNearbyBeacons() {
    // TODO: Use flutter_reactive_ble to scan for SafeSight UUID
    // and decode manufacturer-specific data
    debugPrint('BleBeacon: scanning for nearby SOS beacons');
    return const Stream.empty();
  }

  void dispose() {
    stopBroadcast();
  }
}
