import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/usage_models.dart';

class NativeNetService {
  static const MethodChannel _channel = MethodChannel('ir.helssa.netmeter/traffic');

  Future<bool> hasUsageAccess() async => await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  Future<void> openUsageAccessSettings() => _channel.invokeMethod<void>('openUsageAccessSettings');

  Future<void> requestPhonePermission() async {
    await Permission.phone.request();
  }

  Future<MobileSnapshot> snapshot() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('snapshot') ?? <dynamic, dynamic>{};
    return MobileSnapshot.fromMap(map);
  }

  Future<UsageReport> report(DateTime start, DateTime end) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('report', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    }) ?? <dynamic, dynamic>{};
    return UsageReport.fromMap(map);
  }

  Future<List<UsagePoint>> series(DateTime start, DateTime end, {String? packageName, int points = 24}) async {
    final list = await _channel.invokeListMethod<dynamic>('series', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'points': points,
      if (packageName != null) 'packageName': packageName,
    }) ?? const [];
    return list.whereType<Map>().map(UsagePoint.fromMap).toList();
  }
}
