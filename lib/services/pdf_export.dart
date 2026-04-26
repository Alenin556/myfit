import 'dart:typed_data';

import 'pdf_export_io.dart' if (dart.library.html) 'pdf_export_web.dart' as exp;

/// Скачивание: в вебе — сразу в загрузки; на остальных платформах — share sheet.
Future<void> saveOrSharePdf(Uint8List bytes, {String name = 'plan_pitaniia.pdf'}) =>
    exp.saveOrSharePdf(bytes, name: name);
