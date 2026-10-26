// lib/services/topology_pdf_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';

class TopologyPdfService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Export complete network infrastructure diagram and patch matrix as a professional PDF.
  Future<File> exportTopologyPdf() async {
    final pdf = pw.Document();

    final netDevices = await _db.getNetworkDevices();
    final accessPoints = await _db.getAccessPoints();
    final staticIps = await _db.getStaticIps();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'IT BOX • Network Infrastructure & Topology Map',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Core Routing & Switching Nodes', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Device #', 'Model', 'Gateway IP', 'Location', 'Provider', 'Status'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            data: netDevices.map((d) => [
              d.deviceNumber,
              d.model,
              d.gateway.isNotEmpty ? d.gateway : 'N/A',
              d.deviceLocation,
              d.serviceProvider,
              d.status,
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(
            level: 0,
            child: pw.Text('Wireless Access Points (APs)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['AP #', 'Model', 'Port #', 'Location', 'Notes'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            data: accessPoints.map((ap) => [
              ap.deviceNumber,
              ap.model,
              ap.portNumber.isNotEmpty ? ap.portNumber : 'N/A',
              ap.location,
              ap.notes,
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(
            level: 0,
            child: pw.Text('Static IP Allocation Table (IPAM)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['IP Address', 'Device Name', 'MAC Address', 'Assigned User', 'Subnet'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            data: staticIps.map((ip) => [
              ip['ip_address']?.toString() ?? '',
              ip['device_name']?.toString() ?? '',
              ip['mac_address']?.toString() ?? '',
              ip['assigned_to']?.toString() ?? '',
              ip['subnet']?.toString() ?? '',
            ]).toList(),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/itbox_network_topology_$fileDate.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
