// lib/services/backup_crypto_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/app_database.dart';

/// Service providing SHA-256 payload integrity hashing and
/// opt-in AES-256-GCM authenticated encryption for backups.
class BackupCryptoService {
  static final BackupCryptoService _instance = BackupCryptoService._();
  factory BackupCryptoService() => _instance;
  BackupCryptoService._();

  static const String encryptedFormatIdentifier = 'itbox_backup_encrypted_v1';
  static const int pbkdf2Iterations = 100000;

  /// Calculates a deterministic SHA-256 hex digest of a UTF-8 string.
  String computeSha256(String content) {
    final bytes = utf8.encode(content);
    return crypto.sha256.convert(bytes).toString();
  }

  /// Checks if the raw JSON string is an AES-encrypted backup envelope.
  bool isEncryptedBackup(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return decoded['format'] == encryptedFormatIdentifier;
      }
    } catch (_) {}
    return false;
  }

  /// Encrypts plaintext backup JSON using AES-256-GCM with a user passphrase.
  Future<String> encryptBackup(String plaintextJson, String passphrase) async {
    final algorithm = AesGcm.with256bits();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );

    // Generate cryptographically secure random 16-byte salt
    final rng = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonce = algorithm.newNonce();

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: saltBytes,
    );

    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintextJson),
      secretKey: derivedKey,
      nonce: nonce,
    );

    String appVer = '1.2.0+7';
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        appVer = '${info.version}+${info.buildNumber}';
      }
    } catch (_) {}

    final envelope = <String, dynamic>{
      'format': encryptedFormatIdentifier,
      'schema_version': AppDatabase.currentVersion,
      'app_version': appVer,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': pbkdf2Iterations,
      'salt': base64Encode(saltBytes),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    return jsonEncode(envelope);
  }

  /// Decrypts an AES-256-GCM encrypted backup envelope using the passphrase.
  Future<String> decryptBackup(String encryptedJson, String passphrase) async {
    final envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;
    if (envelope['format'] != encryptedFormatIdentifier) {
      throw const FormatException('Unsupported or unencrypted backup format.');
    }

    final saltBytes = base64Decode(envelope['salt'] as String);
    final nonceBytes = base64Decode(envelope['nonce'] as String);
    final cipherTextBytes = base64Decode(envelope['ciphertext'] as String);
    final macBytes = base64Decode(envelope['mac'] as String);
    final iterations = (envelope['iterations'] as num?)?.toInt() ?? pbkdf2Iterations;

    final algorithm = AesGcm.with256bits();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: saltBytes,
    );

    final secretBox = SecretBox(
      cipherTextBytes,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    try {
      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: derivedKey,
      );
      return utf8.decode(decryptedBytes);
    } catch (_) {
      throw const FormatException('Incorrect password or corrupted encrypted backup.');
    }
  }
}
