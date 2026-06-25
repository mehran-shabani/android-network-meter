import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/usage_models.dart';
import '../utils/formatters.dart';

class UsageBarChart extends StatelessWidget {
  const UsageBarChart({super.key, required this.title, required this.points});
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
                ? const Center(child: Text('داده‌ای برای نمودار نیست.'))
                : BarChart(BarChartData(
                    maxY: maxValue * 1.15,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => Text(formatBytes(v, decimals: 0), style: const TextStyle(fontSize: 9)))),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(toY: points[i].rxBytes.toDouble(), color: Colors.teal, width: 5),
                          BarChartRodData(toY: points[i].txBytes.toDouble(), color: Colors.orange, width: 5),
                        ]),
                    ],
                  )),
          ),
          const SizedBox(height: 8),
          const Text('سبز: دانلود، نارنجی: آپلود', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class TopAppsChart extends StatelessWidget {
  const TopAppsChart({super.key, required this.apps});
  final List<AppUsage> apps;

  @override
  Widget build(BuildContext context) {
    final top = apps.take(8).toList();
    final maxValue = top.fold<double>(0, (m, a) => a.totalBytes > m ? a.totalBytes.toDouble() : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نمودار برنامه‌های پرمصرف', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: top.isEmpty || maxValue == 0 ? const Center(child: Text('داده‌ای نیست.')) : BarChart(BarChartData(
              maxY: maxValue * 1.15,
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              barGroups: [for (var i=0;i<top.length;i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: top[i].totalBytes.toDouble(), width: 16)])],
            )),
          ),
        ]),
      ),
    );
  }
}
