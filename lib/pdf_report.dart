import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'models.dart';

class PdfReport {
  Future<Uint8List> build({
    required UsageReport report,
    required List<UsagePoint> totalSeries,
    AppUsage? selectedApp,
    List<UsagePoint> selectedSeries = const [],
  }) async {
    final doc = pw.Document(title: 'Mobile Data Usage Report');
    final apps = report.apps.take(20).toList();

    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Mobile/SIM Data Usage Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Range: ${report.start} - ${report.end}'),
          pw.Text('Active data SIM: ${report.activeSim?.title ?? 'Unknown'}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Download', bytes(report.totalRxBytes)],
              ['Upload', bytes(report.totalTxBytes)],
              ['Total', bytes(report.totalBytes)],
              ['Apps', apps.length.toString()],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Top apps', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['App', 'Package', 'Download', 'Upload', 'Total'],
            data: apps.map((a) => [a.appName, a.packageName, bytes(a.rxBytes), bytes(a.txBytes), bytes(a.totalBytes)]).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total timeline'),
          _timeline(totalSeries),
          if (selectedApp != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('Selected app timeline: ${selectedApp.appName}'),
            _timeline(selectedSeries),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _timeline(List<UsagePoint> points) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Start', 'End', 'Download', 'Upload', 'Total'],
      data: points.take(30).map((p) => [p.start.toString(), p.end.toString(), bytes(p.rxBytes), bytes(p.txBytes), bytes(p.totalBytes)]).toList(),
      cellStyle: const pw.TextStyle(fontSize: 7),
    );
  }
}
