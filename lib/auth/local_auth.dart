import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Локальная аутентификация (без сервера): соль + SHA-256.
class LocalAuth {
  static String generateSaltB64() {
    final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return base64Encode(b);
  }

  static String hashPassword(String password, String saltB64) {
    final input = utf8.encode('$saltB64$password');
    return sha256.convert(input).toString();
  }

  static bool verify({
    required String login,
    required String password,
    required String? profileLogin,
    required String? passwordHash,
    required String? passwordSaltB64,
  }) {
    if (profileLogin == null ||
        passwordHash == null ||
        passwordSaltB64 == null ||
        password.isEmpty) {
      return false;
    }
    if (profileLogin.toLowerCase().trim() != login.toLowerCase().trim()) {
      return false;
    }
    return hashPassword(password, passwordSaltB64) == passwordHash;
  }
}
