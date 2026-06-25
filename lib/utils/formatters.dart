String formatBytes(num value, {int decimals = 1}) {
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

String formatSpeed(num bytesPerSecond) => '${formatBytes(bytesPerSecond, decimals: 2)}/s';

String formatDateTime(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatPercent(num part, num total, {int decimals = 1}) {
  if (total <= 0 || part <= 0) return '0%';
  return '${((part / total) * 100).toStringAsFixed(decimals)}%';
}
