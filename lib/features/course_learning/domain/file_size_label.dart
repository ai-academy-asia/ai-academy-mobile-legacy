/// A byte count as a file row draws it — "10 MB", the sample's own shape.
/// Binary units (10485760 is "10 MB"); one decimal below 10 of a unit when
/// it is not whole ("1.5 MB"), none otherwise.
///
/// In `domain/` because both sides need it: `data/` labels a material's
/// `size_bytes` with it, and `presentation/` a file the student uploads.
/// [bytes] must not be negative.
String fileSizeLabel(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final whole = value == value.roundToDouble();
  final text = whole || value >= 10
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
