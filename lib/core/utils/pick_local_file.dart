import 'package:file_selector/file_selector.dart';

/// A file the user chose from their device, read into memory.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  /// The file's own name, extension included — e.g. `report.pdf`.
  final String name;

  final List<int> bytes;
}

/// Opens the OS document picker and answers the one file the user chose, or
/// null when they dismissed it.
///
/// The one place this app calls `file_selector`. Callers take it as an
/// injectable `Future<PickedFile?> Function()` so widget and controller tests
/// never reach the platform channel — the same arrangement `openExternalUrl`
/// has.
///
/// No type filter is passed: which files are acceptable is the receiving
/// endpoint's rule, and it answers for itself. A picker the platform could
/// not open, or a file it could not read, throws; the caller shows its own
/// copy for that.
Future<PickedFile?> pickLocalFile() async {
  final file = await openFile();
  if (file == null) return null;
  return PickedFile(name: file.name, bytes: await file.readAsBytes());
}
