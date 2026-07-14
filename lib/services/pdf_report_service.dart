import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/bill.dart';
import '../models/subscription.dart';
import 'company_service.dart';

class PdfReportService {
  static Future<void> generateAndShareMonthlyReport({
    required String periodLabel,
    required List<Expense> expenses,
    required List<Bill> bills,
    required List<Subscription> subscriptions,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final companyName = CompanyService().name;

    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.price);
    final totalBills = bills.fold(0.0, (sum, b) => sum + b.price);
    final totalSubsMonthly = subscriptions.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
    final totalOutflow = totalExpenses + totalBills + totalSubsMonthly;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
            ),
            pw.Text(
              'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'IT BOX — FINANCIAL SUMMARY REPORT',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Period: $periodLabel',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),

          // Executive Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('EXECUTIVE SUMMARY (TOTAL OUTFLOW)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 8),
              _summaryRow('Total Period Expenses:', 'EGP ${fmt.format(totalExpenses)}'),
              _summaryRow('Total Recurring Bills:', 'EGP ${fmt.format(totalBills)}'),
              _summaryRow('Monthly Subscriptions Eqv.:', 'EGP ${fmt.format(totalSubsMonthly)}'),
              pw.Divider(color: PdfColors.grey400),
              _summaryRow('Estimated Total Period Outflow:', 'EGP ${fmt.format(totalOutflow)}', bold: true),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Section 1: Expenses Table
          pw.Text('1. EXPENSES BREAKDOWN (${expenses.length} records)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 6),
          if (expenses.isEmpty)
            pw.Text('No expenses logged for this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Item / Description', 'Details', 'Price (EGP)'],
              data: expenses.map((e) => [
                e.date,
                e.item,
                e.details,
                fmt.format(e.price),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
            ),
          if (expenses.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Expenses Total: EGP ${fmt.format(totalExpenses)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
          pw.SizedBox(height: 20),

          // Section 2: Bills Table
          pw.Text('2. RECURRING BILLS (${bills.length} records)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 6),
          if (bills.isEmpty)
            pw.Text('No bills cataloged.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Person / Account', 'Number', 'Price (EGP)'],
              data: bills.map((b) => [
                b.category,
                b.person,
                b.number,
                fmt.format(b.price),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
            ),
          if (bills.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Bills Total: EGP ${fmt.format(totalBills)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
          pw.SizedBox(height: 20),

          // Section 3: Subscriptions Table
          pw.Text('3. SUBSCRIPTIONS SCHEDULE (${subscriptions.length} records)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 6),
          if (subscriptions.isEmpty)
            pw.Text('No subscriptions recorded.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Service Name', 'Interval', 'Price (EGP)', 'Monthly Equivalent'],
              data: subscriptions.map((s) => [
                s.service,
                s.type,
                fmt.format(s.price),
                fmt.format(s.monthlyEquivalent),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
          if (subscriptions.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Subscriptions Monthly Equivalent Total: EGP ${fmt.format(totalSubsMonthly)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeName = periodLabel.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final file = File('${dir.path}/ITBox_Financial_Report_$safeName.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'IT Box Financial Report ($periodLabel)',
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: bold ? PdfColors.blue900 : PdfColors.black)),
        ],
      ),
    );
  }
}
