class SimInfo {
  const SimInfo({
    required this.subscriptionId,
    required this.slotIndex,
    required this.name,
    required this.isActiveData,
  });

  final int subscriptionId;
  final int slotIndex;
  final String name;
  final bool isActiveData;

  factory SimInfo.fromMap(Map<dynamic, dynamic> map) => SimInfo(
        subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
        slotIndex: (map['slotIndex'] as num?)?.toInt() ?? -1,
        name: (map['name'] ?? 'SIM').toString(),
        isActiveData: map['isActiveData'] == true,
      );

  String get title => 'SIM ${slotIndex + 1} - $name';
}

class MobileSnapshot {
  const MobileSnapshot({
    required this.rxBytes,
    required this.txBytes,
    required this.time,
    this.activeSim,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime time;
  final SimInfo? activeSim;

  factory MobileSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final sim = map['activeSim'];
    return MobileSnapshot(
      rxBytes: (map['rxBytes'] as num?)?.toInt() ?? 0,
      txBytes: (map['txBytes'] as num?)?.toInt() ?? 0,
      time: DateTime.fromMillisecondsSinceEpoch((map['time'] as num?)?.toInt() ?? 0),
      activeSim: sim is Map ? SimInfo.fromMap(sim) : null,
    );
  }
}

class AppUsage {
  const AppUsage({
    required this.uid,
    required this.appName,
    required this.packageName,
    required this.rxBytes,
    required this.txBytes,
  });

  final int uid;
  final String appName;
  final String packageName;
  final int rxBytes;
  final int txBytes;

  int get totalBytes => rxBytes + txBytes;

  factory AppUsage.fromMap(Map<dynamic, dynamic> map) => AppUsage(
        uid: (map['uid'] as num?)?.toInt() ?? -1,
        appName: (map['appName'] ?? 'Unknown').toString(),
        packageName: (map['packageName'] ?? '').toString(),
        rxBytes: (map['rxBytes'] as num?)?.toInt() ?? 0,
        txBytes: (map['txBytes'] as num?)?.toInt() ?? 0,
      );
}

class UsagePoint {
  const UsagePoint({required this.start, required this.end, required this.rxBytes, required this.txBytes});

  final DateTime start;
  final DateTime end;
  final int rxBytes;
  final int txBytes;

  int get totalBytes => rxBytes + txBytes;

  factory UsagePoint.fromMap(Map<dynamic, dynamic> map) => UsagePoint(
        start: DateTime.fromMillisecondsSinceEpoch((map['start'] as num?)?.toInt() ?? 0),
        end: DateTime.fromMillisecondsSinceEpoch((map['end'] as num?)?.toInt() ?? 0),
        rxBytes: (map['rxBytes'] as num?)?.toInt() ?? 0,
        txBytes: (map['txBytes'] as num?)?.toInt() ?? 0,
      );
}

class UsageReport {
  const UsageReport({
    required this.start,
    required this.end,
    required this.totalRxBytes,
    required this.totalTxBytes,
    required this.apps,
    required this.sims,
    this.activeSim,
  });

  final DateTime start;
  final DateTime end;
  final int totalRxBytes;
  final int totalTxBytes;
  final List<AppUsage> apps;
  final List<SimInfo> sims;
  final SimInfo? activeSim;

  int get totalBytes => totalRxBytes + totalTxBytes;

  factory UsageReport.fromMap(Map<dynamic, dynamic> map) => UsageReport(
        start: DateTime.fromMillisecondsSinceEpoch((map['start'] as num?)?.toInt() ?? 0),
        end: DateTime.fromMillisecondsSinceEpoch((map['end'] as num?)?.toInt() ?? 0),
        totalRxBytes: (map['totalRxBytes'] as num?)?.toInt() ?? 0,
        totalTxBytes: (map['totalTxBytes'] as num?)?.toInt() ?? 0,
        apps: ((map['apps'] as List?) ?? const []).whereType<Map>().map(AppUsage.fromMap).toList()
          ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes)),
        sims: ((map['sims'] as List?) ?? const []).whereType<Map>().map(SimInfo.fromMap).toList(),
        activeSim: map['activeSim'] is Map ? SimInfo.fromMap(map['activeSim'] as Map) : null,
      );
}

String bytes(num value, {int decimals = 1}) {
  if (value <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = value.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(unit == 0 ? 0 : decimals)} ${units[unit]}';
}

String speed(num bytesPerSecond) => '${bytes(bytesPerSecond, decimals: 2)}/s';
