// lib/services/executive_health_pdf_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'company_service.dart';

class ExecutiveHealthPdfService {
  static Future<void> generateAndShareExecutiveReport() async {
    final pdf = pw.Document();
    final db = DatabaseHelper();
    final counts = await db.getCounts();
    final expenses = await db.getExpenses();
    final subscriptions = await db.getSubscriptions();
    final bills = await db.getBills();
    final activities = await db.getAuditActivities(limit: 6);

    final totalExpenseCost = expenses.fold(0.0, (sum, e) => sum + e.price);
    final totalMonthlySubs = subscriptions.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
    final totalBills = bills.fold(0.0, (sum, b) => sum + b.price);
    final totalFleetCount = (counts['laptops'] ?? 0) +
        (counts['network_devices'] ?? 0) +
        (counts['printers'] ?? 0) +
        (counts['electronics'] ?? 0) +
        (counts['mifis'] ?? 0);

    final fmt = NumberFormat('#,##0.00', 'en_US');
    final companyName = CompanyService().name;
    final nowFormatted = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'IT DEPARTMENT EXECUTIVE HEALTH INFOGRAPHIC',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('EXECUTIVE SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text('Period: $nowFormatted', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.blue800),
              pw.SizedBox(height: 12),

              // KPI Metric Cards
              pw.Row(
                children: [
                  pw.Expanded(child: _kpiCard('TOTAL MANAGED FLEET', '$totalFleetCount Units', PdfColors.blue50, PdfColors.blue900)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _kpiCard('ACTIVE BORROWS', '${counts['active_borrows'] ?? 0}', PdfColors.teal50, PdfColors.teal900)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _kpiCard('OVERDUE GEAR', '${counts['overdue_borrows'] ?? 0}', (counts['overdue_borrows'] ?? 0) > 0 ? PdfColors.red50 : PdfColors.green50, (counts['overdue_borrows'] ?? 0) > 0 ? PdfColors.red900 : PdfColors.green900)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _kpiCard('OPEN TICKETS', '${counts['open_log_entries'] ?? 0}', PdfColors.amber50, PdfColors.amber900)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Two Column Breakdown
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Fleet Composition
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FLEET COMPOSITION BREAKDOWN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                          pw.SizedBox(height: 8),
                          _statRow('Laptops / Workstations', '${counts['laptops'] ?? 0}'),
                          _statRow('Network Routers & Switches', '${counts['network_devices'] ?? 0}'),
                          _statRow('Access Points (APs)', '${counts['access_points'] ?? 0}'),
                          _statRow('Office Network Printers', '${counts['printers'] ?? 0}'),
                          _statRow('Portable MiFi Hotspots', '${counts['mifis'] ?? 0}'),
                          _statRow('Peripherals & Electronics', '${counts['electronics'] ?? 0}'),
                          pw.Divider(color: PdfColors.grey300),
                          _statRow('Registered Employees', '${counts['employees'] ?? 0}', isBold: true),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Financial Overview
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FINANCIAL RUNWAY & EXPENDITURES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                          pw.SizedBox(height: 8),
                          _statRow('Logged Hardware & Ops Expenses', '${fmt.format(totalExpenseCost)} EGP'),
                          _statRow('Monthly SaaS Subscriptions', '${fmt.format(totalMonthlySubs)} EGP / mo'),
                          _statRow('Recurring Telecom & Utility Bills', '${fmt.format(totalBills)} EGP'),
                          pw.Divider(color: PdfColors.grey300),
                          _statRow('Total Est. Department Run-rate', '${fmt.format(totalExpenseCost + totalMonthlySubs + totalBills)} EGP', isBold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Recent Audit Activities
              pw.Text('RECENT OPERATIONAL AUDIT LOG', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Timestamp', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Action', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Details / Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  if (activities.isEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('No recent activities logged.', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('—', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('—', style: const pw.TextStyle(fontSize: 8))),
                      ],
                    )
                  else
                    ...activities.map(
                      (act) => pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text((act['timestamp'] as String? ?? '').split('T').first, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(act['action_type'] as String? ?? '', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(act['description'] as String? ?? '', style: const pw.TextStyle(fontSize: 8))),
                        ],
                      ),
                    ),
                ],
              ),
              pw.Spacer(),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/IT_Executive_Health_Report.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'IT Executive Health & Fleet Infographic',
      ),
    );
  }

  static pw.Widget _kpiCard(String label, String value, PdfColor bg, PdfColor text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: text), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  static pw.Widget _statRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
