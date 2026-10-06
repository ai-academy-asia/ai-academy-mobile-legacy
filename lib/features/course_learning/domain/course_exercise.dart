import 'course_quiz.dart';
import 'lesson.dart';

/// One lesson's content — the Figma "Exercise Detail" screen.
///
/// Filled by `HttpCourseLearningRepository` from `GET /me/lessons/{lesson_id}`
/// (`course_learning_api_contract_v1.md` §2.3), or by the sample repository.
///
/// From the backend, the content is real: [lessonId], [moduleId],
/// [moduleCaption], [title], [type], [durationLabel], [hasVideo], [summary],
/// [extraSections], [completed], the [materials], the [note] — which is also
/// saved back, through `CourseLearningRepository.saveNote` — the
/// [assignment], with its latest submission and its teacher-provided
/// attachment, and the [quiz] summary. [allMaterials] is what the Course
/// materials tab lists: the lesson's materials and the assignment's
/// attachment together. A backend lesson carries no [assignmentFeedback]
/// and no [assignmentAttachment]: those are the sample's.
class CourseExercise {
  const CourseExercise({
    required this.lessonId,
    required this.moduleId,
    required this.moduleCaption,
    required this.title,
    required this.type,
    required this.durationLabel,
    required this.recordingBadgeLabel,
    required this.summary,
    this.hasVideo = true,
    required this.extraSections,
    required this.materials,
    required this.completed,
    required this.simulatesWrites,
    this.note,
    this.assignmentFeedback = const [],
    this.assignmentAttachment,
    this.assignment,
    this.quiz,
  });

  /// Which lesson this is — `Lesson.id`, the key Exercise Detail is loaded
  /// by.
  final int lessonId;

  /// Which module the lesson belongs to — `module.id`.
  final int moduleId;

  /// The card's caption, e.g. "Modules 2" — the same "Modules N" wording
  /// `CourseModuleCard` already uses, not a separate label invented here.
  final String moduleCaption;

  final String title;

  /// The lesson's `type`.
  final LessonType type;

  /// The video's running time, e.g. "24:15".
  final String durationLabel;

  /// The badge drawn over the video, e.g. "Live Classroom Recording". Empty
  /// when the lesson's [type] has no badge copy, which leaves the badge off.
  final String recordingBadgeLabel;

  /// False when the recording is not up yet — from the backend, when
  /// `video` is `null`. The reference then fills the video area with a
  /// single centred "not uploaded yet" pill and drops the play control, the
  /// duration and the recording badge.
  final bool hasVideo;

  /// The paragraph shown in both the collapsed and expanded states — the
  /// collapsed view simply clips it to a few lines rather than holding a
  /// separate, shorter copy of it.
  final String summary;

  /// Additional sections (e.g. "Pre-training") shown only once the reader
  /// expands past [summary]. Empty when there is nothing more to show.
  final List<CourseExerciseSection> extraSections;

  /// The lesson's own materials — §2.3's `materials`, in the server's order.
  final List<CourseExerciseMaterial> materials;

  /// What the Course materials tab lists: [materials], then the
  /// [assignment]'s teacher-provided [CourseAssignment.attachment], if any.
  ///
  /// The attachment is a reference for the student, not part of their
  /// submission, so it sits with the other materials and opens the same
  /// way. §2.4: it "is the same material object, so both widgets share one
  /// model and one download path". The contract does not say whether an
  /// attachment can also be one of [materials]; one that is keeps its place
  /// there and is not listed a second time.
  List<CourseExerciseMaterial> get allMaterials {
    final attachment = assignment?.attachment;
    if (attachment == null ||
        materials.any((material) => material.id == attachment.id)) {
      return materials;
    }
    return [...materials, attachment];
  }

  /// Whether the student has completed the lesson — server-sent, by the
  /// lesson detail or by `CourseLearningRepository.completeLesson`'s answer
  /// (see [withCompleted]). No control draws it yet.
  final bool completed;

  /// True for the sample exercise, whose assignment submit and material
  /// download are local simulations that never leave the device — the
  /// download button just flips to "downloaded".
  ///
  /// False for a lesson loaded from the backend: the Assignment tab submits
  /// through `CourseLearningRepository.submitAssignment` when the lesson has
  /// an [assignment] (and is disabled when it has none), and a material's
  /// download button fetches a real link (`CourseLearningRepository.
  /// getMaterialDownload`) and opens it. The note is not governed by this —
  /// every repository saves it through `saveNote`.
  final bool simulatesWrites;

  /// The student's own note on this exercise. Null when none has been left
  /// yet — the Note tab's empty/edit state.
  final CourseExerciseNote? note;

  /// Canned mentor responses to an Assignment submission, in order — feeds
  /// the Assignment tab's Mentor Feedback card once a submission exists,
  /// driven by sample data the same way [note] drives the Note tab's two
  /// states.
  ///
  /// Index 0 is shown after the first submit, index 1 after resubmitting,
  /// and so on; the last entry repeats once exhausted. Empty means the
  /// Mentor Feedback card stays on its "No feedback yet" state forever —
  /// used by every exercise that does not care about demonstrating this
  /// flow.
  final List<AssignmentMentorFeedback> assignmentFeedback;

  /// A reference file (e.g. a starter template) attached to the Assignment
  /// tab, downloadable with its own simulated progress — see
  /// `AssignmentAttachmentCard`. Null means this exercise's assignment has
  /// no attachment, and the tab shows only its fields.
  final CourseExerciseMaterial? assignmentAttachment;

  /// The lesson's assignment as the backend holds it — §2.6's `assignment`,
  /// read-only. Null when the lesson has none, and always null for the
  /// sample exercise, whose Assignment tab runs on [assignmentFeedback] and
  /// [assignmentAttachment] instead.
  final CourseAssignment? assignment;

  /// The lesson's quiz summary — §2.7's `quiz`, shown as `QuizPreviewCard`
  /// below the tab card. Null means the lesson has no quiz, and the card
  /// renders nothing.
  final CourseQuiz? quiz;

  /// This exercise with [note] in place of its own — what a successful
  /// `saveNote` leaves the screen holding.
  CourseExercise withNote(CourseExerciseNote note) =>
      _copyWith(note: note, assignment: assignment, quiz: quiz);

  /// This exercise with [quiz] in place of its own — what re-reading the
  /// lesson after a quiz attempt leaves the screen holding.
  CourseExercise withQuiz(CourseQuiz? quiz) =>
      _copyWith(note: note, assignment: assignment, quiz: quiz);

  /// This exercise with [completed] in place of its own — what a successful
  /// `completeLesson` leaves the screen holding, set from the server's answer.
  CourseExercise withCompleted(bool completed) => _copyWith(
    note: note,
    assignment: assignment,
    quiz: quiz,
    completed: completed,
  );

  /// This exercise with [submission] as its assignment's latest — what a
  /// successful `submitAssignment` leaves the screen holding. Only
  /// meaningful when [assignment] is not null; unchanged otherwise.
  CourseExercise withAssignmentSubmission(AssignmentSubmission submission) {
    final assignment = this.assignment;
    if (assignment == null) return this;
    return _copyWith(
      note: note,
      assignment: CourseAssignment(
        id: assignment.id,
        submission: submission,
        attachment: assignment.attachment,
      ),
      quiz: quiz,
    );
  }

  CourseExercise _copyWith({
    required CourseExerciseNote? note,
    required CourseAssignment? assignment,
    required CourseQuiz? quiz,
    bool? completed,
  }) => CourseExercise(
    lessonId: lessonId,
    moduleId: moduleId,
    moduleCaption: moduleCaption,
    title: title,
    type: type,
    durationLabel: durationLabel,
    recordingBadgeLabel: recordingBadgeLabel,
    summary: summary,
    hasVideo: hasVideo,
    extraSections: extraSections,
    materials: materials,
    completed: completed ?? this.completed,
    simulatesWrites: simulatesWrites,
    note: note,
    assignmentFeedback: assignmentFeedback,
    assignmentAttachment: assignmentAttachment,
    assignment: assignment,
    quiz: quiz,
  );
}

/// One heading-and-body block in the expanded description, optionally
/// followed by bullet points (e.g. "Pre-training", with its "Self-Supervised
/// Learning" / "Base Model Creation" bullets).
class CourseExerciseSection {
  const CourseExerciseSection({
    required this.title,
    required this.body,
    this.bullets = const [],
  });

  final String title;
  final String body;
  final List<String> bullets;
}

/// One row in the Course materials tab — §2.4's material: a stored `file`,
/// fetched through `GET /me/materials/{id}/download`, or an external `link`,
/// opened at its own [url].
class CourseExerciseMaterial {
  const CourseExerciseMaterial({
    required this.id,
    required this.name,
    required this.sizeLabel,
    this.url,
  });

  final int id;
  final String name;

  /// Pre-formatted, e.g. "10 MB" — this app has no confirmed source for a
  /// raw byte count to format itself, so it is kept as the display string.
  /// Empty for a link, which has no size.
  final String sizeLabel;

  /// A `link` material's external URL, exactly as the server sent it; null
  /// for a `file`. §2.4: with a link "there is nothing to download".
  final Uri? url;

  /// Whether this is a `link` — opened at [url] rather than downloaded.
  bool get isLink => url != null;
}

/// A note the student has already left on this exercise, with the mentor's
/// own reply — the Note tab's populated state.
class CourseExerciseNote {
  const CourseExerciseNote({
    required this.authorInitials,
    required this.authorName,
    required this.authorLabel,
    required this.message,
    required this.timestampLabel,
  });

  /// e.g. "БП", drawn inside the avatar circle.
  final String authorInitials;

  final String authorName;

  /// e.g. "Me" — the reference shows the note as the student's own, labelled
  /// this way rather than by name a second time.
  final String authorLabel;

  final String message;

  /// Pre-formatted, e.g. "Today, 14:20" — same reasoning as
  /// `CourseExerciseMaterial.sizeLabel`: no confirmed raw timestamp source to
  /// format from yet.
  final String timestampLabel;
}

/// One mentor response to an Assignment submission — a canned entry in the
/// sample's [CourseExercise.assignmentFeedback], or a backend submission's
/// real review ([AssignmentSubmission.feedback]). Shown under the
/// Assignment tab's "Assignment submitted successfully" state — see
/// `AssignmentTab`'s own doc comment.
class AssignmentMentorFeedback {
  const AssignmentMentorFeedback({
    required this.mentorInitials,
    required this.mentorName,
    required this.mentorRole,
    required this.message,
    required this.timestampLabel,
  });

  /// e.g. "БП", drawn inside the avatar circle — same treatment as
  /// `CourseExerciseNote.authorInitials`.
  final String mentorInitials;

  final String mentorName;

  /// e.g. "Lead Mentor", shown under [mentorName].
  final String mentorRole;

  final String message;

  /// Pre-formatted, same reasoning as `CourseExerciseNote.timestampLabel`.
  final String timestampLabel;
}

/// A lesson's assignment, as §2.6 sends it inside `GET /me/lessons/{id}`.
///
/// Only what the screen has a place for is modelled: which assignment it is,
/// the student's latest [submission], and the teacher's [attachment].
/// `title`, `instructions`, `due_date` and `max_score` are real fields the
/// design does not draw yet, so they are not read.
class CourseAssignment {
  const CourseAssignment({required this.id, this.submission, this.attachment});

  final int id;

  /// The latest submission — §2.6 always shows the newest version. Null when
  /// the student has not submitted: the tab's unsubmitted state.
  final AssignmentSubmission? submission;

  /// A reference file or link the teacher attached to the assignment — §2.6's
  /// `attachment`, a §2.4 material. Null when there is none.
  ///
  /// Shown with the lesson's materials (see [CourseExercise.allMaterials]),
  /// never in the Assignment tab: it is not the student's submission, and
  /// opening it has no bearing on submitting.
  final CourseExerciseMaterial? attachment;
}

/// The student's latest submission to a [CourseAssignment]. Server-sent in
/// full; nothing here is derived.
class AssignmentSubmission {
  const AssignmentSubmission({
    required this.id,
    required this.version,
    required this.status,
    required this.submittedAt,
    this.link,
    this.description,
    this.feedback,
  });

  final int id;

  /// 1 for the first submission, +1 on every resubmission.
  final int version;

  final AssignmentSubmissionStatus status;

  final DateTime submittedAt;

  /// Either may be null — §2.6 requires a link *or* a file, and makes the
  /// description optional. The submission's file itself is not read.
  final String? link;
  final String? description;

  /// The mentor's review of this submission. Null until it is reviewed —
  /// the Mentor Feedback card's "No feedback yet" state.
  final AssignmentMentorFeedback? feedback;
}

/// A submission's `status`, per §2.6. [unknown] holds anything else, the
/// way `LessonType.unknown` does: a value the backend adds later must not
/// take the whole lesson down with it.
enum AssignmentSubmissionStatus {
  /// `"submitted"` — waiting for the mentor.
  submitted,

  /// `"reviewed"` — feedback and score present.
  reviewed,

  /// Any value this build does not know.
  unknown;

  static AssignmentSubmissionStatus fromApi(String value) => switch (value) {
    'submitted' => submitted,
    'reviewed' => reviewed,
    _ => unknown,
  };
}
