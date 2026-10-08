import 'package:flutter/foundation.dart';

import '../../../core/utils/open_external_url.dart';
import '../../course_learning/domain/course_learning_failure.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../course_learning/presentation/course_learning_strings.dart';
import '../domain/certificate_entry.dart';
import '../domain/certificate_list_repository.dart';

/// State for the Certificate screen (Issue #155): the student's certificate
/// cards, and each issued certificate's download.
///
/// The download fetches a fresh pre-signed link on every tap (§2.9 — it
/// expires, so it is never cached) and opens it outside the app through the
/// same [openExternalUrl] lesson materials use. While one is in flight its
/// button is busy and a second tap does nothing.
class CertificateListController extends ChangeNotifier {
  CertificateListController({
    required this._repository,
    required this._courseLearning,
    Future<bool> Function(Uri url)? openUrl,
  }) : _openUrl = openUrl ?? openExternalUrl;

  final CertificateListRepository _repository;
  final CourseLearningRepository _courseLearning;
  final Future<bool> Function(Uri url) _openUrl;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<CertificateEntry> _entries = const [];
  String? _errorMessage;
  final Set<String> _downloading = {};

  bool get loading => _loading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  List<CertificateEntry> get entries => _entries;

  /// The list's failure, as the screen shows it. Null when it loaded.
  String? get errorMessage => _errorMessage;

  bool isDownloading(String certNumber) => _downloading.contains(certNumber);

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      _entries = await _repository.getCertificates();
    } on CourseLearningFailure catch (failure) {
      _errorMessage = CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      _errorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  /// Fetches [certNumber]'s download link and opens it. Answers null once the
  /// OS has taken the link, or the copy to show when it could not be had or
  /// opened. Ignored (null) while that certificate is already in flight.
  Future<String?> download(String certNumber) async {
    if (_downloading.contains(certNumber)) return null;
    _downloading.add(certNumber);
    _notify();
    try {
      final link = await _courseLearning.getCertificateDownload(certNumber);
      final opened = await _openUrl(link.url);
      return opened ? null : CourseLearningStrings.unexpectedError;
    } on CourseLearningFailure catch (failure) {
      return CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      return CourseLearningStrings.unexpectedError;
    } finally {
      _downloading.remove(certNumber);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
