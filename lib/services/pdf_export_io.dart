import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Скачивание/отправка PDF на мобильных и десктопе (не веб).
Future<void> saveOrSharePdf(Uint8List bytes, {String name = 'plan_pitaniia.pdf'}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path)], subject: 'План питания');
}
