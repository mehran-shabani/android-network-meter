import 'package:flutter_test/flutter_test.dart';
import 'package:android_network_meter/utils/formatters.dart';

void main() {
  test('formatBytes uses binary units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(1024 * 1024), '1.0 MB');
  });

  test('formatSpeed appends per second', () {
    expect(formatSpeed(2048), '2.00 KB/s');
  });

  test('formatPercent handles empty totals', () {
    expect(formatPercent(10, 0), '0%');
    expect(formatPercent(25, 100), '25.0%');
  });
}
