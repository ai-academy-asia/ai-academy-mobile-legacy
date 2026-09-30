import 'package:flutter/foundation.dart';

import '../../../core/utils/open_external_url.dart';
import '../../../core/utils/pick_local_file.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import '../domain/uploaded_file.dart';
import 'course_learning_strings.dart';

/// Loads one lesson's content, saves the student's note on it, opens its
/// materials' downloads, uploads the file its assignment submission carries,
/// and submits that assignment.
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
    Future<PickedFile?> Function()? pickFile,
  }) : _openUrl = openUrl ?? openExternalUrl,
       _pickFile = pickFile ?? pickLocalFile;

  final CourseLearningRepository _repository;

  /// Hands a material's download link to the OS — [openExternalUrl] unless a
  /// test injects its own. Answers whether the link was opened.
  final Future<bool> Function(Uri url) _openUrl;

  /// Asks the student for a file — [pickLocalFile] unless a test injects its
  /// own. Answers null when they chose none.
  final Future<PickedFile?> Function() _pickFile;

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
  bool _pickingAssignmentFile = false;
  int? _assignmentFileUploadSizeBytes;
  UploadedFile? _assignmentFile;
  String? _assignmentFileErrorMessage;

  /// Bumped whenever an upload in flight stops being wanted — a cancel — so
  /// its answer is dropped when it arrives.
  int _assignmentFileUploadGeneration = 0;

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

  /// True while an assignment file's upload is in flight.
  bool get uploadingAssignmentFile => _assignmentFileUploadSizeBytes != null;

  /// How large the file being uploaded is, or null when none is. The
  /// repository reports no progress, so this total is all there is to show.
  int? get assignmentFileUploadSizeBytes => _assignmentFileUploadSizeBytes;

  /// The uploaded file the next [submitAssignment] will attach, or null.
  /// Dropped once a submission has carried it.
  UploadedFile? get assignmentFile => _assignmentFile;

  /// User-facing copy for the last failed [pickAndUploadAssignmentFile], or
  /// null. Its own line, so it shows under the file area rather than under
  /// the form's Submit.
  String? get assignmentFileErrorMessage => _assignmentFileErrorMessage;

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

  /// Asks the student for a file and uploads it (§2.8 `POST /me/files`), so
  /// the next [submitAssignment] can attach it. Answers true once
  /// [assignmentFile] holds the stored file.
  ///
  /// Answers false, changing nothing, when the student picks no file. A
  /// failure leaves [assignmentFile] as it was and puts copy in
  /// [assignmentFileErrorMessage]: the repository's failure by kind, or the
  /// generic line when the picker or the file could not be read. Which types
  /// and sizes are acceptable is the backend's answer, not checked here.
  /// Ignored (false) with no assignment loaded, or while a pick, an upload
  /// or a submit is already in flight.
  Future<bool> pickAndUploadAssignmentFile() async {
    if (_exercise?.assignment == null ||
        _pickingAssignmentFile ||
        uploadingAssignmentFile ||
        _submittingAssignment) {
      return false;
    }

    _pickingAssignmentFile = true;
    _assignmentFileErrorMessage = null;
    _notify();

    final PickedFile? picked;
    try {
      picked = await _pickFile();
    } catch (_) {
      _assignmentFileErrorMessage = CourseLearningStrings.unexpectedError;
      return false;
    } finally {
      _pickingAssignmentFile = false;
      _notify();
    }
    if (picked == null) return false;

    final generation = ++_assignmentFileUploadGeneration;
    _assignmentFileUploadSizeBytes = picked.bytes.length;
    _notify();

    try {
      final file = await _repository.uploadFile(
        fileName: picked.name,
        bytes: picked.bytes,
      );
      // Cancelled meanwhile: the stored file is simply never attached, and
      // §2.8 has the backend delete one nobody attaches.
      if (generation != _assignmentFileUploadGeneration) return false;
      _assignmentFile = file;
      return true;
    } on CourseLearningFailure catch (failure) {
      if (generation == _assignmentFileUploadGeneration) {
        _assignmentFileErrorMessage = CourseLearningStrings.messageFor(
          failure.kind,
        );
      }
      return false;
    } catch (_) {
      if (generation == _assignmentFileUploadGeneration) {
        _assignmentFileErrorMessage = CourseLearningStrings.unexpectedError;
      }
      return false;
    } finally {
      if (generation == _assignmentFileUploadGeneration) {
        _assignmentFileUploadSizeBytes = null;
        _notify();
      }
    }
  }

  /// Stops waiting for the upload in flight: its answer, whenever it comes,
  /// is dropped. The request itself cannot be recalled. Ignored with no
  /// upload in flight.
  void cancelAssignmentFileUpload() {
    if (!uploadingAssignmentFile) return;
    _assignmentFileUploadGeneration++;
    _assignmentFileUploadSizeBytes = null;
    _notify();
  }

  /// Drops [assignmentFile], so the next submission carries no file. Ignored
  /// while a submit is in flight — that submit is already sending it.
  void removeAssignmentFile() {
    if (_assignmentFile == null || _submittingAssignment) return;
    _assignmentFile = null;
    _notify();
  }

  /// Submits [link] and [description] (each when not blank) and
  /// [assignmentFile] (when one is uploaded) to the loaded lesson's
  /// assignment — a first submission or a resubmission, the same call. On
  /// success the loaded exercise holds the submission the server answered
  /// with, [assignmentFile] is dropped — it is attached now — and this
  /// answers true. On failure the exercise and the file are untouched,
  /// [assignmentSubmitErrorMessage] says why (404 with this feature's own
  /// "assignment not found" line), and this answers false. Ignored (false)
  /// with no assignment loaded, or while a submit or an upload is in flight.
  Future<bool> submitAssignment({String? link, String? description}) async {
    final assignment = _exercise?.assignment;
    if (assignment == null ||
        _submittingAssignment ||
        uploadingAssignmentFile) {
      return false;
    }

    _submittingAssignment = true;
    _assignmentSubmitErrorMessage = null;
    _notify();

    String? orNull(String? text) {
      final trimmed = text?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    try {
      final submission = await _repository.submitAssignment(
        assignment.id,
        link: orNull(link),
        description: orNull(description),
        fileId: _assignmentFile?.id,
      );
      _assignmentFile = null;
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
