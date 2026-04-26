import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../personal_goal.dart' show PersonalGoal, personalGoalLabel;
import 'daily_menu_generator.dart';
import 'meal_plan_narrative.dart' show MealPlanNarrative, regimeTipsText;
import 'pdf_export.dart';

class MenuPdfService {
  Future<Uint8List> buildDailyMenuPdf({
    required String userName,
    required int targetKcal,
    required PersonalGoal goal,
    required GeneratedMenu menu,
    MealPlanNarrative? narrative,
  }) async {
    final ttf = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(ttf);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: font),
        ),
        build: (c) {
          return [
            pw.Text(
              'My Pro Health Nutrition',
              style: pw.TextStyle(font: font, fontSize: 16),
            ),
            pw.SizedBox(height: 4),
            if (narrative != null) ...[
              pw.Text(
                narrative.title,
                style: pw.TextStyle(font: font, fontSize: 13),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                narrative.introBody,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Основные параметры',
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                narrative.kcalLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                narrative.proteinLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                narrative.fatLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                narrative.carbLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                narrative.waterLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                narrative.mealsPerDayLine,
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.SizedBox(height: 6),
            ] else ...[
              pw.Text(
                'План питания на день (ориентир)',
                style: pw.TextStyle(font: font, fontSize: 14),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Пациент: $userName', style: pw.TextStyle(font: font)),
              pw.Text(
                'Цель: ${personalGoalLabel(goal)}',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Суточная норма: $targetKcal ккал (сумма по блюдам: ${menu.totalKcal} ккал)',
                style: pw.TextStyle(font: font),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Text(
              'Пример меню на день (≈$targetKcal ккал)',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColor.fromInt(0xFF1565C0),
              ),
            ),
            pw.SizedBox(height: 4),
            if (menu.rows.isEmpty)
              pw.Text(
                'Нет данных по продуктам',
                style: pw.TextStyle(font: font, fontSize: 10),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0),
                  1: const pw.FlexColumnWidth(2.2),
                  2: const pw.FlexColumnWidth(0.55),
                  3: const pw.FlexColumnWidth(0.45),
                  4: const pw.FlexColumnWidth(0.45),
                  5: const pw.FlexColumnWidth(0.45),
                  6: const pw.FlexColumnWidth(0.45),
                },
                children: [
                  pw.TableRow(
                    children: _pdfCells(font, [
                      'Приём',
                      'Продукт',
                      'Г',
                      'Б',
                      'Ж',
                      'У',
                      'ккал',
                    ], header: true),
                  ),
                  for (final r in menu.rows) ..._tableRowsForMenuRow(font, r),
                  pw.TableRow(
                    children: _pdfCells(font, [
                      'Итого за день',
                      '',
                      '',
                      '${menu.totalProteinG}',
                      '${menu.totalFatG}',
                      '${menu.totalCarbG}',
                      '${menu.totalKcal}',
                    ]),
                  ),
                ],
              ),
            pw.SizedBox(height: 6),
            if (narrative != null) ...[
              pw.Text(
                narrative.footerNote,
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              pw.SizedBox(height: 6),
              ...regimeTipsText()
                  .split('\n')
                  .map(
                    (e) => pw.Text(
                      e,
                      style: pw.TextStyle(font: font, fontSize: 8),
                    ),
                  ),
            ],
            pw.SizedBox(height: 6),
            pw.Text(
              'Справочник продуктов в приложении; согласуйте план с врачом/диетологом.',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _pdfCells(
    pw.Font font,
    List<String> cells, {
    bool header = false,
  }) {
    final fs = header ? 8.0 : 7.0;
    return cells
        .map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(
              e,
              style: pw.TextStyle(
                font: font,
                fontSize: fs,
                fontWeight: header ? pw.FontWeight.bold : null,
              ),
            ),
          ),
        )
        .toList();
  }

  Future<void> sharePdf(
    Uint8List bytes, {
    String name = 'plan_pitaniia.pdf',
  }) async {
    await saveOrSharePdf(bytes, name: name);
  }

  List<pw.TableRow> _tableRowsForMenuRow(pw.Font font, MenuRow row) {
    if (row.items.isEmpty) {
      return [
        pw.TableRow(
          children: _pdfCells(font, [
            row.title,
            row.products,
            row.grams,
            '${row.proteinG}',
            '${row.fatG}',
            '${row.carbG}',
            '${row.kcal}',
          ]),
        ),
      ];
    }
    var first = true;
    return row.items.map((it) {
      final tr = pw.TableRow(
        children: _pdfCells(font, [
          first ? row.title : '',
          it.name,
          '${it.grams}',
          '${it.proteinG}',
          '${it.fatG}',
          '${it.carbG}',
          '${it.kcal}',
        ]),
      );
      first = false;
      return tr;
    }).toList();
  }
}
