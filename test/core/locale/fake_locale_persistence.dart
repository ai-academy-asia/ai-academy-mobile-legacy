import 'package:aia_mobile/core/locale/locale_preference.dart';

/// [LocalePreferencePersistence] in memory, failing on demand.
class FakeLocalePersistence implements LocalePreferencePersistence {
  FakeLocalePersistence({this.stored, this.failRead = false});

  /// What [read] answers.
  String? stored;

  /// [read] throws instead.
  bool failRead;

  /// [write] throws instead (the value is not kept).
  bool failWrite = false;

  /// Every value [write] was asked to keep, in order — failed ones too.
  final List<String> writes = [];

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('storage unavailable');
    return stored;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (failWrite) throw StateError('storage unavailable');
    stored = value;
  }
}
