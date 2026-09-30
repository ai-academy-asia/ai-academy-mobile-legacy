import 'package:flutter/foundation.dart';

import '../../../core/utils/open_external_url.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import 'course_learning_strings.dart';

/// Loads one lesson's content, saves the student's note on it, opens its
/// materials' downloads, and submits its assignment link.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseLearningController`,
/// [errorMessage] included: `GET /me/lessons/{lesson_id}` is a real fallible
/// source, so a failure reaches the screen as copy rather than as an
/// exception thrown through `build`.
class CourseExerciseDetailController extends ChangeNotifier {
  CourseExerciseDetailController({
    required this._repository,
    required this.lessonId,
    Future<bool> Function(Uri url)? openUrl,
  }) : _openUrl = openUrl ?? openExternalUrl;

  final CourseLearningRepository _repository;

  /// Hands a material's download link to the OS — [openExternalUrl] unless a
  /// test injects its own. Answers whether the link was opened.
  final Future<bool> Function(Uri url) _openUrl;

  /// Which lesson this controller loads — `Lesson.id`. Fixed for the
  /// controller's lifetime, same reasoning as `CourseLearningController.
  /// courseSlug`.
  final int lessonId;

  bool _disposed = false;
  bool _loading = false;
  CourseExercise? _exercise;
  String? _errorMessage;
  bool _savingNote = false;
  String? _noteSaveErrorMessage;
  final Set<int> _downloadingMaterialIds = {};
  final Set<int> _openedMaterialIds = {};
  final Map<int, String> _materialDownloadErrors = {};
  bool _submittingAssignment = false;
  String? _assignmentSubmitErrorMessage;

  bool get loading => _loading;
  CourseExercise? get exercise => _exercise;

  /// True while a [saveNote] is in flight.
  bool get savingNote => _savingNote;

  /// User-facing copy for the last failed [saveNote], or null. Kept apart
  /// from [errorMessage]: a failed save leaves the loaded lesson on screen.
  String? get noteSaveErrorMessage => _noteSaveErrorMessage;

  /// True while a [submitAssignment] is in flight.
  bool get submittingAssignment => _submittingAssignment;

  /// User-facing copy for the last failed [submitAssignment], or null. Kept
  /// apart from [errorMessage], like [noteSaveErrorMessage].
  String? get assignmentSubmitErrorMessage => _assignmentSubmitErrorMessage;

  /// True while [downloadMaterial] is fetching or opening [materialId]'s
  /// link.
  bool isDownloadingMaterial(int materialId) =>
      _downloadingMaterialIds.contains(materialId);

  /// True once [materialId]'s link has been opened — the button's
  /// "downloaded" state.
  bool isMaterialOpened(int materialId) =>
      _openedMaterialIds.contains(materialId);

  /// User-facing copy for [materialId]'s last failed download, or null. Per
  /// material, so a failure shows under the row that failed.
  String? materialDownloadErrorMessage(int materialId) =>
      _materialDownloadErrors[materialId];

  /// User-facing copy for the last failure, or null. Cleared at the start of
  /// every [load] so a retry does not show the previous attempt's message
  /// while the new one is in flight.
  String? get errorMessage => _errorMessage;

  /// Fetches the lesson. Safe to call again — that is the retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _exercise = await _repository.getExercise(lessonId);
    } on CourseLearningFailure catch (failure) {
      // Dropped, not kept, for the reason `CourseLearningController` gives:
      // a failed reload shows its error rather than data that may be stale.
      _exercise = null;
      _errorMessage = CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      _exercise = null;
      _errorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Saves [content] as the lesson's note. On success the loaded exercise
  /// holds the note the repository returned — the server's author and
  /// timestamp, not a local copy — and this answers true. On failure the
  /// exercise is untouched, [noteSaveErrorMessage] says why, and this
  /// answers false. Ignored (false) with no lesson loaded or a save already
  /// in flight.
  Future<bool> saveNote(String content) async {
    if (_exercise == null || _savingNote) return false;

    _savingNote = true;
    _noteSaveErrorMessage = null;
    _notify();

    try {
      final note = await _repository.saveNote(lessonId, content);
      // Re-read, not captured before the await: a reload may have replaced
      // the exercise meanwhile, and the saved note belongs on the current one.
      final current = _exercise;
      if (current != null) _exercise = current.withNote(note);
      return true;
    } on CourseLearningFailure catch (failure) {
      _noteSaveErrorMessage = CourseLearningStrings.messageFor(failure.kind);
      return false;
    } catch (_) {
      _noteSaveErrorMessage = CourseLearningStrings.unexpectedError;
      return false;
    } finally {
      _savingNote = false;
      _notify();
    }
  }

  /// Submits [link] (and [description], when not blank) to the loaded
  /// lesson's assignment — a first submission or a resubmission, the same
  /// call. On success the loaded exercise holds the submission the server
  /// answered with, and this answers true. On failure the exercise is
  /// untouched, [assignmentSubmitErrorMessage] says why (404 with this
  /// feature's own "assignment not found" line), and this answers false.
  /// Ignored (false) with no assignment loaded or a submit already in
  /// flight.
  Future<bool> submitAssignment({
    required String link,
    String? description,
  }) async {
    final assignment = _exercise?.assignment;
    if (assignment == null || _submittingAssignment) return false;

    _submittingAssignment = true;
    _assignmentSubmitErrorMessage = null;
    _notify();

    final trimmedDescription = description?.trim();
    try {
      final submission = await _repository.submitAssignment(
        assignment.id,
        link: link.trim(),
        description: trimmedDescription == null || trimmedDescription.isEmpty
            ? null
            : trimmedDescription,
      );
      // Re-read, as `saveNote` does: a reload may have replaced the exercise.
      final current = _exercise;
      if (current != null) {
        _exercise = current.withAssignmentSubmission(submission);
      }
      return true;
    } on CourseLearningFailure catch (failure) {
      _assignmentSubmitErrorMessage =
          failure.kind == CourseLearningFailureKind.notFound
          ? CourseLearningStrings.assignmentNotFound
          : CourseLearningStrings.messageFor(failure.kind);
      return false;
    } catch (_) {
      _assignmentSubmitErrorMessage = CourseLearningStrings.unexpectedError;
      return false;
    } finally {
      _submittingAssignment = false;
      _notify();
    }
  }

  /// Asks for a fresh link to [materialId] (§2.4 — a pre-signed URL valid
  /// for five minutes, so never cached) and opens it outside the app.
  /// Answers true once the OS has taken the link.
  ///
  /// A failure leaves the material un-opened and puts copy in
  /// [materialDownloadErrorMessage]: the repository's failure by kind (404
  /// with this feature's own "file not found" line rather than the course's),
  /// or the generic line when the OS would not open the link. Ignored (false)
  /// while that material is already in flight.
  Future<bool> downloadMaterial(int materialId) async {
    if (_downloadingMaterialIds.contains(materialId)) return false;

    _downloadingMaterialIds.add(materialId);
    _materialDownloadErrors.remove(materialId);
    _notify();

    try {
      final download = await _repository.getMaterialDownload(materialId);
      final opened = await _openUrl(download.url);
      if (opened) {
        _openedMaterialIds.add(materialId);
      } else {
        _materialDownloadErrors[materialId] =
            CourseLearningStrings.unexpectedError;
      }
      return opened;
    } on CourseLearningFailure catch (failure) {
      _materialDownloadErrors[materialId] =
          failure.kind == CourseLearningFailureKind.notFound
          ? CourseLearningStrings.materialNotFound
          : CourseLearningStrings.messageFor(failure.kind);
      return false;
    } catch (_) {
      _materialDownloadErrors[materialId] =
          CourseLearningStrings.unexpectedError;
      return false;
    } finally {
      _downloadingMaterialIds.remove(materialId);
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
