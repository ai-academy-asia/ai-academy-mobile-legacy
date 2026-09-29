import '../domain/junior_learning_map.dart';

/// Every word on the Junior Home screen.
///
/// The tab labels are Mongolian, verbatim from the frame. Two things to know
/// about the middle one:
///
/// * It is not the adult app's "Хичээл" — the Junior design names that tab
///   differently, so this feature carries its own copy rather than reusing
///   `HomeStrings`.
/// * The frame spells it **"Сурлагын явц"**. Issue #98's written description
///   says "Сургалтын явц". The export is the stated source of truth and
///   `DEVELOPMENT_RULES.md` §6 asks for copy verbatim from the design, so the
///   frame's spelling is what ships; the difference is flagged for review
///   because the two words are not synonyms.
///
/// The card, node and certificate copy the reference draws in English is left
/// in English for the same reason `CourseLearningStrings` does: translating it
/// would be inventing wording the design never specified.
abstract final class JuniorHomeStrings {
  static const String navHome = 'Нүүр';
  static const String navProgress = 'Сурлагын явц';
  static const String navProfile = 'Профайл';

  /// The map as a whole, for a screen reader arriving at the scroll view.
  static const String learningMap = 'Learning map';

  // --- Node accessibility --------------------------------------------------
  //
  // The nodes draw no text at all — a tick, a scan mark, a padlock — so
  // without these a screen reader would find five unlabelled boxes.

  static const String nodeCompleted = 'completed';
  static const String nodeCurrent = 'current lesson';
  static const String nodeLocked = 'locked';

  static String nodeLabel(int number, JuniorNodeState state) =>
      'Lesson $number, ${switch (state) {
        JuniorNodeState.completed => nodeCompleted,
        JuniorNodeState.current => nodeCurrent,
        JuniorNodeState.locked => nodeLocked,
      }}';
}
