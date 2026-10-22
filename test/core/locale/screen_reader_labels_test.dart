import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_video_header.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_progress_header.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_screen.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_strings.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/courses/fake_course_repository.dart';
import '../../features/notifications/fake_notification_repository.dart';
import '../../features/teacher/fake_schedule_change_repository.dart';
import '../../support/screenshot.dart' show loadAppFonts;

/// Issue #509: the screen-reader labels of the back, play, close and unread
/// controls follow the selected language, through ARB like every other
/// string. None is ever drawn.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved labels, by key.
  const labels = <String, ({String mongolian, String english})>{
    'commonBack': (mongolian: 'Буцах', english: 'Back'),
    'videoPlay': (mongolian: 'Тоглуулах', english: 'Play'),
    'quizClose': (mongolian: 'Хаах', english: 'Close'),
    'notificationUnread': (mongolian: 'Шинэ', english: 'Unread'),
  };

  String expected(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? labels[key]!.mongolian
      : labels[key]!.english;

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final strings = L10n.of(language);
        expect(
          {
            'commonBack': strings.commonBack,
            'videoPlay': strings.videoPlay,
            'quizClose': strings.quizClose,
            'notificationUnread': strings.notificationUnread,
          },
          {for (final key in labels.keys) key: expected(key, language)},
        );
      });
    }

    test('read differently from one another in both languages, so a '
        'control wired to the wrong key cannot pass', () {
      expect({for (final l in labels.values) l.mongolian}, hasLength(4));
      expect({for (final l in labels.values) l.english}, hasLength(4));
    });
  });

  group('every member that carries one reads its key', () {
    final members = <(String, String Function(), String)>[
      ('AppBackButton.label', () => AppBackButton.label, 'commonBack'),
      (
        'CourseLearningStrings.back',
        () => CourseLearningStrings.back,
        'commonBack',
      ),
      (
        'CourseDetailStrings.back',
        () => CourseDetailStrings.back,
        'commonBack',
      ),
      (
        'CourseLearningStrings.play',
        () => CourseLearningStrings.play,
        'videoPlay',
      ),
      (
        'CourseLearningStrings.quizClose',
        () => CourseLearningStrings.quizClose,
        'quizClose',
      ),
      (
        'NotificationStrings.unread',
        () => NotificationStrings.unread,
        'notificationUnread',
      ),
    ];
    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, read, key) in members) {
          expect(read(), expected(key, language), reason: name);
        }
      });
    }
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// [key]'s label in [language] is announced once, and the other
  /// language's is not.
  void expectAnnounced(String key, LocalePreference language) {
    final other = language == LocalePreference.mongolian
        ? LocalePreference.english
        : LocalePreference.mongolian;
    expect(find.bySemanticsLabel(expected(key, language)), findsOneWidget);
    expect(find.bySemanticsLabel(expected(key, other)), findsNothing);
  }

  for (final language in LocalePreference.values) {
    group('announced in ${language.name}', () {
      setUp(() => locale.setPreference(language));

      testWidgets('the shared back button', (tester) async {
        await pump(tester, const Scaffold(body: AppBackButton()));
        expectAnnounced('commonBack', language);
      });

      testWidgets('the lesson video\'s back and play buttons', (tester) async {
        await pump(
          tester,
          Scaffold(
            body: ExerciseVideoHeader(
              durationLabel: '24:15',
              recordingBadgeLabel: '',
              onPlay: () {},
            ),
          ),
        );
        expectAnnounced('commonBack', language);
        expectAnnounced('videoPlay', language);
      });

      testWidgets('the quiz close button', (tester) async {
        await pump(
          tester,
          Scaffold(
            body: QuizProgressHeader(current: 1, total: 3, onClose: () {}),
          ),
        );
        expectAnnounced('quizClose', language);
      });

      testWidgets('the course detail back button', (tester) async {
        await pump(
          tester,
          CourseDetailScreen(
            slug: 'summer-bootcamp',
            repository: FakeCourseRepository(courseDetail: sampleCourse()),
          ),
        );
        expectAnnounced('commonBack', language);
      });

      testWidgets('an unread notification row, its whole label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final repository = FakeNotificationRepository(
          notifications: [
            sampleNotification(
              id: 3,
              title: 'Title only',
              body: null,
              createdAt: DateTime.now().subtract(
                const Duration(days: 1, minutes: 1),
              ),
            ),
          ],
        );
        await pump(
          tester,
          NotificationScreen(
            center: NotificationCenter(repository: repository),
            scheduleChangeRepository: FakeScheduleChangeRepository(),
          ),
        );

        final row = find.ancestor(
          of: find.text('Title only'),
          matching: find.byType(NotificationTile),
        );
        expect(
          tester.getSemantics(row).label,
          '${expected('notificationUnread', language)}, Title only, 1d',
        );
        semantics.dispose();
      });
    });
  }

  group('switching language on a mounted screen', () {
    testWidgets('the labels change, the screen keeps its state, and Back '
        'still goes back', (tester) async {
      await pump(tester, const _Home());
      await tester.tap(find.text('home: 0'));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const _LessonPage()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'typed');
      expect(find.bySemanticsLabel('Буцах'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Тоглуулах'), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      // The shared back button and the video's, both in English now.
      expect(find.bySemanticsLabel('Back'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Буцах'), findsNothing);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      expect(find.text('typed'), findsOneWidget);

      // Play still answers.
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pump();
      expect(find.text('played: 1'), findsOneWidget);

      // Back still goes back, to Home as it was left.
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(find.byType(_LessonPage), findsNothing);
      expect(find.text('home: 1'), findsOneWidget);
    });

    testWidgets('an unread row\'s label changes and the row still opens', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = FakeNotificationRepository(
        notifications: [
          sampleNotification(
            id: 3,
            title: 'Title only',
            body: null,
            createdAt: DateTime.now().subtract(
              const Duration(days: 1, minutes: 1),
            ),
          ),
        ],
      );
      await pump(
        tester,
        NotificationScreen(
          center: NotificationCenter(repository: repository),
          scheduleChangeRepository: FakeScheduleChangeRepository(),
        ),
      );
      final row = find.ancestor(
        of: find.text('Title only'),
        matching: find.byType(NotificationTile),
      );
      expect(tester.getSemantics(row).label, 'Шинэ, Title only, 1d');

      await locale.setEnglish(true);
      await tester.pump();

      expect(tester.getSemantics(row).label, 'Unread, Title only, 1d');
      // Still unread: switching language marks nothing read.
      expect(repository.markCalls, isEmpty);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(repository.markCalls, [3]);
      semantics.dispose();
    });
  });
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: GestureDetector(
        onTap: () => setState(() => _count++),
        child: Text('home: $_count'),
      ),
    ),
  );
}

/// A lesson page: the shared back button, the video header (its own back
/// and play buttons) and a text field holding state.
class _LessonPage extends StatefulWidget {
  const _LessonPage();

  @override
  State<_LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<_LessonPage> {
  final _text = TextEditingController();
  int _played = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const AppBackButton(),
        SizedBox(
          height: 240,
          child: ExerciseVideoHeader(
            durationLabel: '24:15',
            recordingBadgeLabel: '',
            onPlay: () => setState(() => _played++),
          ),
        ),
        TextField(controller: _text),
        Text('played: $_played'),
      ],
    ),
  );
}
