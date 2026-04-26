import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'telegram_sender_api.dart';

enum ContactMethod { gmail, telegram }

/// Краткая сводка для отправки (без полного текста плана и таблицы).
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.sendSummary,
  });

  final String sendSummary;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _emailController = TextEditingController();

  ContactMethod _method = ContactMethod.gmail;
  bool _telegramLinked = false;
  bool _busy = false;
  String? _linkCode;
  Timer? _autoLinkTimer;
  bool _autoSent = false;

  final TelegramSenderApi _tgApi = TelegramSenderApi(
    baseUrl: 'https://myfit-telegram-worker.myhealthnutrition-alenin.workers.dev',
  );

  String _ensureLinkCode() {
    final current = _linkCode;
    if (current != null && current.isNotEmpty) {
      return current;
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final ms = DateTime.now().millisecondsSinceEpoch;
    var v = ms;
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buf.write(chars[v % chars.length]);
      v ~/= chars.length;
    }
    final code = buf.toString();
    _linkCode = code;
    return code;
  }

  String? _validate() {
    if (_method == ContactMethod.gmail) {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        return 'Введите email';
      }
      final ok = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s.]+', caseSensitive: false)
          .hasMatch(email);
      if (!ok) {
        return 'Введите корректный email';
      }
    }
    return null;
  }

  Future<void> _copySummary() async {
    await Clipboard.setData(ClipboardData(text: widget.sendSummary));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сводка скопирована в буфер обмена')),
    );
  }

  Future<void> _openTelegramTarget() async {
    final code = _ensureLinkCode();
    final uri = Uri.parse('https://t.me/myhealthnutritionbot?start=$code');
    if (!await canLaunchUrl(uri)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть: $uri')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitGmail() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    final email = _emailController.text.trim();
    try {
      await _tgApi.sendEmail(to: email, text: widget.sendSummary);
      await Clipboard.setData(ClipboardData(text: widget.sendSummary));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сводка отправлена на $email. Копия в буфере обмена.'),
        ),
      );
    } on EmailNotConfigured {
      await Clipboard.setData(ClipboardData(text: widget.sendSummary));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сервер не настроен: сводка скопирована, откроем Gmail. Оформите письмо вручную.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      await _openGmailOrMailto();
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: widget.sendSummary));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сервер: $e. Сводка в буфере, откроем почту.'),
          duration: const Duration(seconds: 5),
        ),
      );
      await _openGmailOrMailto();
    }
  }

  Future<void> _openGmailOrMailto() async {
    final email = _emailController.text.trim();
    const title = 'План питания (сводка)';
    final body = widget.sendSummary;
    const cap = 5000;
    var urlBody = body;
    if (urlBody.length > cap) {
      urlBody = '${body.substring(0, cap - 200)}\n\n… (полный текст в буфере).';
    }
    final gUrl = 'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(email)}'
        '&su=${Uri.encodeComponent(title)}'
        '&body=${Uri.encodeComponent(urlBody)}';
    final gUri = Uri.parse(gUrl);
    try {
      if (await canLaunchUrl(gUri)) {
        await launchUrl(gUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    final mUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': title,
        'body': body,
      },
    );
    if (await canLaunchUrl(mUri)) {
      await launchUrl(mUri, mode: LaunchMode.platformDefault);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть почту. Текст в буфере обмена.'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_method == ContactMethod.gmail) {
      await _submitGmail();
      return;
    }
    await _copySummary();
    await _openTelegramTarget();
    _startAutoLinkAndSend();
  }

  void _stopAutoLinkTimer() {
    _autoLinkTimer?.cancel();
    _autoLinkTimer = null;
  }

  void _startAutoLinkAndSend() {
    _stopAutoLinkTimer();
    setState(() {
      _busy = true;
      _telegramLinked = false;
      _autoSent = false;
    });
    final code = _ensureLinkCode();
    final startedAt = DateTime.now();
    _autoLinkTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) {
        return;
      }
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 60)) {
        _stopAutoLinkTimer();
        if (!mounted) {
          return;
        }
        setState(() {
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось привязать за 60 секунд. Открой бота /start $code, затем попробуй ещё раз.',
            ),
          ),
        );
        return;
      }
      try {
        final linked = await _tgApi.linkStatus(code);
        if (!mounted) {
          return;
        }
        if (!linked) {
          return;
        }
        setState(() {
          _telegramLinked = true;
        });
        if (_autoSent) {
          return;
        }
        _autoSent = true;
        await _tgApi.sendPlan(code: code, text: widget.sendSummary);
        if (!mounted) {
          return;
        }
        _stopAutoLinkTimer();
        setState(() {
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сводка отправлена в Telegram')),
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _stopAutoLinkTimer();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отправка плана')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Параметры для отправки',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  widget.sendSummary,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Куда отправить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ContactMethod>(
              segments: const [
                ButtonSegment(
                  value: ContactMethod.gmail,
                  label: Text('Почта'),
                  icon: Icon(Icons.mail_outline),
                ),
                ButtonSegment(
                  value: ContactMethod.telegram,
                  label: Text('Telegram'),
                  icon: Icon(Icons.send_outlined),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (set) {
                setState(() {
                  _method = set.first;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_method == ContactMethod.gmail)
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email получателя',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              )
            else
              const Text(
                'Бот и код привязки. После нажатия кнопки откроется Telegram.',
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _method == ContactMethod.gmail
                    ? 'Отправить на email'
                    : 'Открыть бота и привязать',
              ),
            ),
            if (_method == ContactMethod.telegram) ...[
              const SizedBox(height: 10),
              Text(
                'Код: ${_ensureLinkCode()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _busy
                    ? 'Ожидаю привязку и отправку…'
                    : (_telegramLinked ? 'Привязано.' : 'Ожидаю привязку.'),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _copySummary,
              icon: const Icon(Icons.copy),
              label: const Text('Скопировать сводку'),
            ),
          ],
        ),
      ),
    );
  }
}
