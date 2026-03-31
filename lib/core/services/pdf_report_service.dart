import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:jal_dharan/core/models/groundwater_data.dart';
import 'package:jal_dharan/core/services/dashboard_api_service.dart';
import 'package:intl/intl.dart';

class PdfReportService {
  /// Generate the PDF document and immediately offer to print/share it.
  static Future<void> generateAndShowReport(GroundwaterData data, String aiSummary) async {
    final pdf = pw.Document(
      title: 'Water Health Report',
      author: 'Jal Dharan AI',
    );

    // Load fonts (use default for simplicity in standard Latin)
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final now = DateTime.now();
    final dateString = DateFormat('MMM d, yyyy - hh:mm a').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        header: (context) => _buildHeader(dateString),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildAISection(aiSummary),
          pw.SizedBox(height: 30),
          _buildSensorDataRow(data),
          pw.SizedBox(height: 20),
          _buildQualityDataBlock(data),
        ],
      ),
    );

    // Provide the PDF directly to the system print/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Water_Report_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }

  static pw.Widget _buildHeader(String dateString) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Jal Dharan Sensor Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1a237e'), // Deep blue
              ),
            ),
            pw.Text(
              dateString,
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildAISection(String aiSummary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#f8fafc'),
        border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AI Summary & Future Predictions',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0f172a'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            aiSummary,
            style: const pw.TextStyle(
              fontSize: 11,
              lineSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSensorDataRow(GroundwaterData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Current Sensor Readings',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _dataBox('TDS Level', '${data.tdsLevel.toStringAsFixed(1)} ppm', data.tdsStatus),
            _dataBox('pH Level', data.phLevel.toStringAsFixed(1), data.phStatus),
            _dataBox('Water Depth', '${data.sensorDistanceCm.toStringAsFixed(1)} cm', data.remainingPercentage),
          ],
        ),
      ],
    );
  }

  static pw.Widget _dataBox(String title, String value, String status) {
    final isWarning = status.contains('High') || status.contains('Low') || status.contains('Acidic') || status.contains('Alkaline');
    final statusColor = isWarning ? PdfColors.orange700 : PdfColors.green700;

    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(status, style: pw.TextStyle(fontSize: 9, color: statusColor, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildQualityDataBlock(GroundwaterData data) {
    if (data.waterHealthAI == null) return pw.SizedBox();

    final health = data.waterHealthAI!;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Automated Quality Assessment',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _tableRow('Contamination Score', '${health.contaminationScore.toStringAsFixed(0)} / 100'),
            _tableRow('Health Risk', '${health.contaminationLevel} (${health.diseaseRisk})'),
            _tableRow('Alert Tags', health.healthRiskTags.join(', ')),
            _tableRow('Recommended Action', health.recommendedAction),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _tableRow(String key, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
