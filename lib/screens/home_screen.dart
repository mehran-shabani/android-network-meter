import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/usage_models.dart';
import '../utils/formatters.dart';
import '../services/native_net_service.dart';
import '../services/pdf_report_service.dart';
import '../widgets/usage_charts.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _native = NativeNetService();
  final _pdf = PdfReport();

  Timer? _timer;
  MobileSnapshot? _previous;
  double _down = 0;
  double _up = 0;
  SimInfo? _activeSim;

  bool _usageAccess = false;
  bool _loading = false;
  String? _error;

  DateTime _end = DateTime.now();
  late DateTime _start = _end.subtract(const Duration(days: 1));
  int _points = 24;

  UsageReport? _report;
  List<UsagePoint> _totalSeries = const [];
  AppUsage? _selectedApp;
  List<UsagePoint> _selectedSeries = const [];
  String _query = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _readSpeed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _checkUsageAccess();
    await _readSpeed();
    await _loadReport();
  }

  Future<void> _checkUsageAccess() async {
    final ok = await _native.hasUsageAccess();
    if (mounted) setState(() => _usageAccess = ok);
  }

  Future<void> _readSpeed() async {
    try {
      final now = await _native.snapshot();
      final prev = _previous;
      _previous = now;
      if (prev == null) {
        if (mounted) setState(() => _activeSim = now.activeSim);
        return;
      }
      final seconds = now.time.difference(prev.time).inMilliseconds / 1000.0;
      if (seconds <= 0) return;
      if (!mounted) return;
      setState(() {
        _down = ((now.rxBytes - prev.rxBytes).clamp(0, 1 << 60)) / seconds;
        _up = ((now.txBytes - prev.txBytes).clamp(0, 1 << 60)) / seconds;
        _activeSim = now.activeSim;
      });
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    await _checkUsageAccess();
    if (!_usageAccess) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _native.report(_start, _end);
      final total = await _native.series(_start, _end, points: _points);
      List<UsagePoint> selected = const [];
      if (_selectedApp != null) {
        selected = await _native.series(_start, _end, points: _points, packageName: _selectedApp!.packageName);
      }
      if (!mounted) return;
      setState(() {
        _report = report;
        _activeSim = report.activeSim ?? _activeSim;
        _totalSeries = total;
        _selectedSeries = selected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _quick(Duration duration) {
    final now = DateTime.now();
    setState(() {
      _end = now;
      _start = now.subtract(duration);
      _selectedApp = null;
      _selectedSeries = const [];
    });
    _loadReport();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'انتخاب بازه',
      cancelText: 'لغو',
      confirmText: 'تایید',
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      _selectedApp = null;
      _selectedSeries = const [];
    });
    _loadReport();
  }

  Future<void> _selectApp(AppUsage app) async {
    setState(() => _selectedApp = app);
    try {
      final series = await _native.series(_start, _end, points: _points, packageName: app.packageName);
      if (mounted) setState(() => _selectedSeries = series);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPdf() async {
    final report = _report;
    if (report == null) return;
    final bytesData = await _pdf.build(
      report: report,
      totalSeries: _totalSeries,
      selectedApp: _selectedApp,
      selectedSeries: _selectedSeries,
    );
    await Printing.sharePdf(bytes: bytesData, filename: 'mobile_data_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Meter سیمکارت'),
        actions: [IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _SpeedCard(down: _down, up: _up, activeSim: _activeSim, isCellularActive: _previous?.isCellularActive ?? false),
            const SizedBox(height: 10),
            _PermissionCard(
              enabled: _usageAccess,
              onUsage: () => _native.openUsageAccessSettings(),
              onPhone: () async {
                await _native.requestPhonePermission();
                await _readSpeed();
              },
            ),
            const SizedBox(height: 10),
            _RangeCard(
              start: _start,
              end: _end,
              points: _points,
              onQuick: _quick,
              onPick: _pickRange,
              onPoints: (v) {
                setState(() => _points = v);
                _loadReport();
              },
            ),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null) _ErrorCard(_error!),
            if (!_usageAccess) const _InfoCard('برای مصرف هر برنامه باید Usage Access را از تنظیمات اندروید فعال کنی.'),
            if (report != null) ...[
              const SizedBox(height: 10),
              _SummaryCard(report: report, onPdf: _exportPdf),
              const SizedBox(height: 10),
              _Chart(title: 'نمودار مصرف کل دیتای سیمکارت', points: _totalSeries),
              if (_selectedApp != null) ...[
                const SizedBox(height: 10),
                _Chart(title: 'نمودار مصرف ${_selectedApp!.appName}', points: _selectedSeries),
              ],
              const SizedBox(height: 10),
              TopAppsChart(apps: report.apps),
              const SizedBox(height: 10),
              _AppsList(apps: report.apps, selected: _selectedApp, query: _query, onQuery: (v) => setState(() => _query = v), onTap: _selectApp),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.down, required this.up, required this.activeSim, required this.isCellularActive});
  final double down;
  final double up;
  final SimInfo? activeSim;
  final bool isCellularActive;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('سرعت لحظه‌ای دیتای سیمکارت', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Metric('دانلود', formatSpeed(down), Icons.download_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric('آپلود', formatSpeed(up), Icons.upload_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric('کل', formatSpeed(down + up), Icons.speed_rounded)),
            ]),
            const SizedBox(height: 10),
            Text('سیم فعال دیتا: ${activeSim?.title ?? 'نامشخص'}'),
            Text(isCellularActive ? 'شبکه فعال فعلی موبایل است.' : 'شبکه فعال فعلی موبایل نیست؛ اگر Wi‑Fi روشن باشد سرعت لحظه‌ای سیمکارت ممکن است صفر یا غیرفعال باشد.'),
          ]),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon),
          const SizedBox(height: 6),
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.enabled, required this.onUsage, required this.onPhone});
  final bool enabled;
  final VoidCallback onUsage;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('دسترسی‌ها', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(enabled ? 'Usage Access فعال است' : 'Usage Access فعال نیست'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: onUsage, icon: const Icon(Icons.settings), label: const Text('Usage Access')),
              OutlinedButton.icon(onPressed: onPhone, icon: const Icon(Icons.sim_card), label: const Text('اجازه سیمکارت')),
            ]),
          ]),
        ),
      );
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.start, required this.end, required this.points, required this.onQuick, required this.onPick, required this.onPoints});
  final DateTime start;
  final DateTime end;
  final int points;
  final ValueChanged<Duration> onQuick;
  final VoidCallback onPick;
  final ValueChanged<int> onPoints;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('بازه گزارش', style: Theme.of(context).textTheme.titleMedium),
            Text('${_fmt(start)} تا ${_fmt(end)}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ActionChip(label: const Text('۱ ساعت'), onPressed: () => onQuick(const Duration(hours: 1))),
              ActionChip(label: const Text('۶ ساعت'), onPressed: () => onQuick(const Duration(hours: 6))),
              ActionChip(label: const Text('۲۴ ساعت'), onPressed: () => onQuick(const Duration(days: 1))),
              ActionChip(label: const Text('۷ روز'), onPressed: () => onQuick(const Duration(days: 7))),
              ActionChip(label: const Text('۳۰ روز'), onPressed: () => onQuick(const Duration(days: 30))),
              ActionChip(label: const Text('دستی'), onPressed: onPick),
            ]),
            DropdownButton<int>(
              value: points,
              items: const [12, 24, 48, 96].map((e) => DropdownMenuItem(value: e, child: Text('$e نقطه'))).toList(),
              onChanged: (v) {
                if (v != null) onPoints(v);
              },
            ),
          ]),
        ),
      );

  static String _fmt(DateTime d) => '${d.year}/${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.onPdf});
  final UsageReport report;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('خلاصه مصرف', style: Theme.of(context).textTheme.titleMedium)),
              FilledButton.icon(onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
            ]),
            Row(children: [
              Expanded(child: _Metric('دانلود', formatBytes(report.totalRxBytes), Icons.download)),
              const SizedBox(width: 8),
              Expanded(child: _Metric('آپلود', formatBytes(report.totalTxBytes), Icons.upload)),
              const SizedBox(width: 8),
              Expanded(child: _Metric('کل', formatBytes(report.totalBytes), Icons.data_usage)),
            ]),
            const SizedBox(height: 8),
            Text('سیم فعال گزارش: ${report.activeSim?.title ?? 'نامشخص'}'),
            const Text('توجه: وای‌فای حذف شده و فقط TYPE_MOBILE محاسبه می‌شود.'),
          ]),
        ),
      );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.title, required this.points});
  final String title;
  final List<UsagePoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(0, (m, p) => p.totalBytes > m ? p.totalBytes.toDouble() : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: points.isEmpty || maxValue == 0
                ? const Center(child: Text('داده‌ای برای نمودار نیست'))
                : BarChart(BarChartData(
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(x: i, barRods: [BarChartRodData(toY: points[i].totalBytes.toDouble())]),
                    ],
                  )),
          ),
        ]),
      ),
    );
  }
}

class _AppsList extends StatelessWidget {
  const _AppsList({required this.apps, required this.selected, required this.query, required this.onQuery, required this.onTap});
  final List<AppUsage> apps;
  final AppUsage? selected;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<AppUsage> onTap;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty ? apps : apps.where((a) => a.appName.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q)).toList();
    return Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('مصرف هر برنامه', style: Theme.of(context).textTheme.titleMedium)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'جستجوی نام یا بسته برنامه'), onChanged: onQuery)),
          if (visible.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('برنامه‌ای پیدا نشد.')),
          ...visible.take(100).map((app) => ListTile(
                selected: selected?.packageName == app.packageName,
                title: Text(app.appName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr),
                trailing: Text(formatBytes(app.totalBytes)),
                onTap: () => onTap(app),
              )),
        ]),
      );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Text(text)));
}
