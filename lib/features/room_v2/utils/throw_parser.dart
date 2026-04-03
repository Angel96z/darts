String formatThrowLabel(dynamic item) {
  if (item is Map) {
    final number = item['number'];
    final multiplier = item['multiplier'] ?? 1;
    final isMiss = item['isMiss'] == true;

    if (isMiss) return 'MISS';
    if (number == null) return '-';

    final prefix = multiplier == 3
        ? 'T'
        : multiplier == 2
        ? 'D'
        : 'S';

    return '$prefix$number';
  }

  if (item is int) return item.toString();

  return '-';
}
