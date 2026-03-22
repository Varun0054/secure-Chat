import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _secureStorage = const FlutterSecureStorage();

  // Core Cryptography Algorithms (Forced Pure Dart engines to bypass all WebCrypto inconsistencies)
  final _x25519 = DartX25519();
  final _aesGcm = DartAesGcm.with256bits();
  final _hkdf = DartHkdf(hmac: DartHmac.sha256(), outputLength: 32);

  // In-memory cache for Room SecretKeys to prevent battery drain
  final Map<String, SecretKey> _roomKeysCache = {};

  SimpleKeyPair? _keyPair;

  // Storage Identifiers
  static const _privateKeyStorageKey = 'e2ee_private_key';
  static const _publicKeyStorageKey = 'e2ee_public_key';

  bool get isInitialized => _keyPair != null;

  /// Loads or generates the device's X25519 Key Pair (Identity Persistence)
  Future<void> initialize() async {
    try {
      final privateKeyB64 = await _secureStorage.read(
        key: _privateKeyStorageKey,
      );
      final publicKeyB64 = await _secureStorage.read(key: _publicKeyStorageKey);

      if (privateKeyB64 != null && publicKeyB64 != null) {
        // Identity Persistence: Load existing keys
        final privateKeyBytes = base64Decode(privateKeyB64);
        final publicKeyBytes = base64Decode(publicKeyB64);

        _keyPair = SimpleKeyPairData(
          privateKeyBytes,
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
        debugPrint('EncryptionService: Loaded persistent X25519 Key Pair.');
      } else {
        // Generate new identity
        _keyPair = await _x25519.newKeyPair();
        final privateKeyBytes = await _keyPair!.extractPrivateKeyBytes();
        final publicKeyBytes = (await _keyPair!.extractPublicKey()).bytes;

        await _secureStorage.write(
          key: _privateKeyStorageKey,
          value: base64Encode(privateKeyBytes),
        );
        await _secureStorage.write(
          key: _publicKeyStorageKey,
          value: base64Encode(publicKeyBytes),
        );
        debugPrint(
          'EncryptionService: Generated and saved new X25519 Key Pair.',
        );
      }
    } catch (e) {
      debugPrint('EncryptionService Error during init: $e');
      rethrow;
    }
  }

  /// Returns Base64 Public Key to upload to Supabase profiles
  Future<String?> getPublicKeyBase64() async {
    if (_keyPair == null) return null;
    final pk = await _keyPair!.extractPublicKey();
    return base64Encode(pk.bytes);
  }

  /// ECDH + HKDF Handshake: Derives a strong Key Encryption Key (KEK)
  Future<SecretKey> _deriveKEK(String targetPublicKeyBase64) async {
    if (_keyPair == null) throw Exception('EncryptionService not initialized');

    final targetKeyBytes = base64Decode(targetPublicKeyBase64);
    final targetPublicKey = SimplePublicKey(
      targetKeyBytes,
      type: KeyPairType.x25519,
    );

    // 1. ECDH Shared Secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: targetPublicKey,
    );

    // 2. HKDF Derivation with strict domain separation context
    final derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('secure-chat-salt-v1'), // Salt
      info: utf8.encode('room-key-encryption-v1'), // Strict usage context
    );

    return derivedKey;
  }

  /// Generates a random AES-256 room key and encrypts it using the derived KEK.
  /// Used during new room creation.
  Future<Map<String, dynamic>> encryptRoomKeyForUser(
    String targetPublicKeyBase64,
    SecretKey roomKey,
  ) async {
    final kek = await _deriveKEK(targetPublicKeyBase64);
    final roomKeyBytes = await roomKey.extractBytes();

    debugPrint('=== ENCRYPT ROOM KEY ===');
    debugPrint('Target PubKey: $targetPublicKeyBase64');
    debugPrint('My PubKey: ${await getPublicKeyBase64()}');
    debugPrint('KEK: ${base64Encode(await kek.extractBytes())}');
    debugPrint('RoomKey: ${base64Encode(roomKeyBytes)}');

    final nonce = _aesGcm.newNonce();
    final encrypted = await _aesGcm.encrypt(
      roomKeyBytes,
      secretKey: kek,
      nonce: nonce,
    );

    // Use concatenation to bypass WebCrypto fragmentation bugs
    return {
      'payload': base64Encode(encrypted.concatenation()),
      'nl': nonce.length,
      'ml': encrypted.mac.bytes.length,
    };
  }

  /// Decrypts the room key pulled from Supabase using our private key and the sender's public key.
  Future<SecretKey> decryptRoomKey(
    String senderPublicKeyBase64,
    Map<String, dynamic> encryptedKeyPayload,
  ) async {
    final kek = await _deriveKEK(senderPublicKeyBase64);

    debugPrint('=== DECRYPT ROOM KEY ===');
    debugPrint('Sender PubKey: $senderPublicKeyBase64');
    debugPrint('My PubKey: ${await getPublicKeyBase64()}');
    debugPrint('KEK: ${base64Encode(await kek.extractBytes())}');

    SecretBox secretBox;

    if (encryptedKeyPayload.containsKey('payload')) {
      final concat = base64Decode(encryptedKeyPayload['payload']);
      secretBox = SecretBox.fromConcatenation(
        concat,
        nonceLength: encryptedKeyPayload['nl'],
        macLength: encryptedKeyPayload['ml'],
      );
    } else {
      // FIX For v1 Room Keys: Force concatenation manually so WebCrypto parses it!
      final cipherText = base64Decode(encryptedKeyPayload['c']);
      final nonce = base64Decode(encryptedKeyPayload['n']);
      final mac = base64Decode(encryptedKeyPayload['m']);

      final concat = Uint8List(nonce.length + cipherText.length + mac.length);
      concat.setAll(0, nonce);
      concat.setAll(nonce.length, cipherText);
      concat.setAll(nonce.length + cipherText.length, mac);

      secretBox = SecretBox.fromConcatenation(
        concat,
        nonceLength: nonce.length,
        macLength: mac.length,
      );
    }

    final roomKeyBytes = await _aesGcm.decrypt(secretBox, secretKey: kek);

    return SecretKey(roomKeyBytes);
  }

  /// Helper: Creates a brand new AES-256 Room Key.
  Future<SecretKey> generateNewRoomKey() async {
    return await _aesGcm.newSecretKey();
  }

  /// Cache the Room Key in-memory
  void cacheRoomKey(String roomId, SecretKey key) {
    _roomKeysCache[roomId] = key;
  }

  /// Checks if room key is already in RAM
  bool isRoomKeyCached(String roomId) {
    return _roomKeysCache.containsKey(roomId);
  }

  /// Fetches cached room key
  SecretKey? getCachedRoomKey(String roomId) {
    return _roomKeysCache[roomId];
  }

  /// Encrypts a plaintext message for sending.
  /// Returns atomic JSON as specified in the plan.
  Future<String> encryptMessage(String roomId, String plaintext) async {
    final roomKey = _roomKeysCache[roomId];
    if (roomKey == null) {
      throw Exception('Room key not cached in memory for room: $roomId');
    }

    final rkB = base64Encode(await roomKey.extractBytes());
    debugPrint('=== ENCRYPT DIAGNOSTICS ===');
    debugPrint('Using Room Key: $rkB');

    final plaintextBytes = utf8.encode(plaintext);
    final nonce = _aesGcm.newNonce();
    debugPrint('Nonce (len ${nonce.length}): ${base64Encode(nonce)}');

    final encrypted = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: roomKey,
      nonce: nonce,
    );

    // Self-Test Fast Diagnosis Trick
    try {
      final testBox = SecretBox(
        encrypted.cipherText,
        nonce: encrypted.nonce,
        mac: encrypted.mac,
      );
      final testDecrypt = await _aesGcm.decrypt(testBox, secretKey: roomKey);
      debugPrint(
        'Self-Test Decrypt Success! Text: ${utf8.decode(testDecrypt)}',
      );
    } catch (e) {
      debugPrint('Self-Test Decrypt FAILED instantly: $e');
    }

    final payload = {
      'payload': base64Encode(encrypted.concatenation()),
      'nl': nonce.length,
      'ml': encrypted.mac.bytes.length,
      'v': 2,
    };

    return jsonEncode(payload);
  }

  /// Decrypts an incoming message payload.
  Future<String> decryptMessage(String roomId, String jsonPayload) async {
    final roomKey = _roomKeysCache[roomId];
    if (roomKey == null) {
      throw Exception('Room key not cached in memory for room: $roomId');
    }

    final rkB = base64Encode(await roomKey.extractBytes());
    debugPrint('=== DECRYPT DIAGNOSTICS ===');
    debugPrint('Using Room Key: $rkB');

    final payload = jsonDecode(jsonPayload);
    final version = payload['v'] ?? payload['version'] ?? 1;
    debugPrint('Incoming Version: $version');

    SecretBox secretBox;

    if (version == 2 || payload.containsKey('payload')) {
      final concat = base64Decode(payload['payload']);
      secretBox = SecretBox.fromConcatenation(
        concat,
        nonceLength: payload['nl'],
        macLength: payload['ml'],
      );
    } else {
      final cipherText = base64Decode(payload['ciphertext']);
      final nonce = base64Decode(payload['nonce']);
      final mac = base64Decode(payload['mac']);

      debugPrint(
        'V1 Extraction -> Nonce: ${base64Encode(nonce)}, Mac: ${base64Encode(mac)}',
      );

      final concat = Uint8List(nonce.length + cipherText.length + mac.length);
      concat.setAll(0, nonce);
      concat.setAll(nonce.length, cipherText);
      concat.setAll(nonce.length + cipherText.length, mac);

      secretBox = SecretBox.fromConcatenation(
        concat,
        nonceLength: nonce.length,
        macLength: mac.length,
      );
    }

    final decryptedBytes = await _aesGcm.decrypt(secretBox, secretKey: roomKey);

    return utf8.decode(decryptedBytes);
  }

  /// Clear session keys (on logout)
  void clearMemoryCache() {
    _roomKeysCache.clear();
    _keyPair = null;
    debugPrint('EncryptionService: Cleared in-memory cache.');
  }

  /// Total wipe (use only when absolutely wiping the device identity)
  Future<void> deletePersistentIdentity() async {
    await _secureStorage.delete(key: _privateKeyStorageKey);
    await _secureStorage.delete(key: _publicKeyStorageKey);
    clearMemoryCache();
  }
}
