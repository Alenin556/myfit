import 'dart:convert';

import 'package:http/http.dart' as http;

class TelegramSenderApi {
  TelegramSenderApi({
    required this.baseUrl,
    this.apiKey,
  });

  /// Базовый URL Worker, например `https://myfit-telegram-worker.example.workers.dev`
  final String baseUrl;
  final String? apiKey;

  Uri _u(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: query,
    );
  }

  Map<String, String> _headers() {
    final h = <String, String>{'content-type': 'application/json'};
    if (apiKey != null && apiKey!.isNotEmpty) h['x-api-key'] = apiKey!;
    return h;
  }

  Future<bool> linkStatus(String code) async {
    final res = await http.get(_u('/link-status', {'code': code}), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('link-status failed: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['linked'] == true;
  }

  Future<void> sendPlan({required String code, required String text}) async {
    final res = await http.post(
      _u('/send'),
      headers: _headers(),
      body: jsonEncode({'code': code, 'text': text}),
    );
    if (res.statusCode != 200) {
      throw Exception('send failed: ${res.statusCode} ${res.body}');
    }
  }

  /// [EmailNotConfigured] — в Worker не задан `RESEND_API_KEY` (см. README).
  Future<void> sendEmail({
    required String to,
    required String text,
    String subject = 'План питания',
  }) async {
    final res = await http.post(
      _u('/send-email'),
      headers: _headers(),
      body: jsonEncode({
        'to': to,
        'text': text,
        'subject': subject,
      }),
    );
    if (res.statusCode == 501) {
      throw const EmailNotConfigured();
    }
    if (res.statusCode != 200) {
      throw Exception('send-email: ${res.statusCode} ${res.body}');
    }
  }
}

class EmailNotConfigured implements Exception {
  const EmailNotConfigured();
}

