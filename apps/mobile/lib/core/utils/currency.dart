String formatTry(double value) => '${value.toStringAsFixed(2)} ₺';

/// Turkish price display used on the plan screens: 1899 -> "1.899 TL",
/// 4309.2 -> "4.309,20 TL".
String formatTl(double value) {
  final cents = (value * 100).round();
  final digits = (cents ~/ 100).toString();
  final fraction = cents % 100;
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return fraction == 0
      ? '$grouped TL'
      : '$grouped,${fraction.toString().padLeft(2, '0')} TL';
}
