/// One module's exercise/lesson content — the Figma "Exercise Detail" screen.
///
/// **Sample data only.** Same status as `CourseModule`: no backend endpoint
/// for exercise/lesson content, assignments, materials or notes exists yet —
/// every field here is this app's own choice for local sample data, not a
/// claim about a future API's shape.
class CourseExercise {
  const CourseExercise({
    required this.moduleId,
    required this.moduleCaption,
    required this.title,
    required this.durationLabel,
    required this.recordingBadgeLabel,
    required this.summary,
    required this.extraSections,
    required this.materials,
    this.note,
  });

  /// Which module this exercise belongs to — `CourseModule.id`.
  final int moduleId;

  /// The card's caption, e.g. "Modules 2" — the same "Modules N" wording
  /// `CourseModuleCard` already uses, not a separate label invented here.
  final String moduleCaption;

  final String title;

  /// The video's running time, e.g. "24:15".
  final String durationLabel;

  /// The badge drawn over the video, e.g. "Live Classroom Recording".
  final String recordingBadgeLabel;

  /// The paragraph shown in both the collapsed and expanded states — the
  /// collapsed view simply clips it to a few lines rather than holding a
  /// separate, shorter copy of it.
  final String summary;

  /// Additional sections (e.g. "Pre-training") shown only once the reader
  /// expands past [summary]. Empty when there is nothing more to show.
  final List<CourseExerciseSection> extraSections;

  final List<CourseExerciseMaterial> materials;

  /// The student's own note on this exercise. Null when none has been left
  /// yet — the Note tab's empty/edit state.
  final CourseExerciseNote? note;
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

/// One row in the Course materials tab.
class CourseExerciseMaterial {
  const CourseExerciseMaterial({
    required this.id,
    required this.name,
    required this.sizeLabel,
  });

  final int id;
  final String name;

  /// Pre-formatted, e.g. "10 MB" — this app has no confirmed source for a
  /// raw byte count to format itself, so it is kept as the display string.
  final String sizeLabel;
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
