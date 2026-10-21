import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_card.dart';
import 'package:aia_mobile/features/courses/presentation/widgets/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screenshot.dart' show loadAppFonts;
import 'cohorts/fake_cohort_repository.dart';
import 'courses/fake_course_repository.dart';

/// Issue #501: the API's bilingual `{"mn", "en"}` text is shown in the
/// selected language where it is chosen on screen — the course card, the
/// cohort card and the contract card — with Mongolian whenever English
/// carries no text. Mongolian (the default) reads exactly as before.
void main() {
  // The app's own font, so cards are measured as they draw.
  setUpAll(loadAppFonts);
  tearDown(() => ContentLanguage.prefersEnglish = false);

  Future<void> pump(WidgetTester tester, Widget card) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 1400) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('course card', () {
    // The sample: title {en: Summer Bootcamp, mn: Зуны бүтээлч кэмп}, and a
    // Mongolian-only tagline.
    testWidgets('Mongolian: the Mongolian title, as before', (tester) async {
      await pump(tester, CourseCard(course: sampleCourse()));

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
      expect(find.text('Summer Bootcamp'), findsNothing);
    });

    testWidgets('English: the English title; a Mongolian-only tagline stays '
        'Mongolian', (tester) async {
      ContentLanguage.prefersEnglish = true;
      await pump(tester, CourseCard(course: sampleCourse()));

      expect(find.text('Summer Bootcamp'), findsOneWidget);
      expect(find.text('Зуны бүтээлч кэмп'), findsNothing);
      expect(find.text('3 долоо хоногийн эрчимжүүлсэн'), findsOneWidget);
    });

    testWidgets('English with a blank English title: the Mongolian title', (
      tester,
    ) async {
      ContentLanguage.prefersEnglish = true;
      await pump(
        tester,
        CourseCard(
          course: sampleCourse(
            title: const LocalizedText(en: '   ', mn: 'Зуны бүтээлч кэмп'),
          ),
        ),
      );

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
    });
  });

  group('cohort card', () {
    // The sample cohort's course: {en: Summer Bootcamp, mn: Зуны бүтээлч кэмп}.
    testWidgets('Mongolian: the course\'s Mongolian title', (tester) async {
      await pump(tester, CohortCard(cohort: sampleCohort(), enrolled: true));

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
    });

    testWidgets('English: the course\'s English title', (tester) async {
      ContentLanguage.prefersEnglish = true;
      await pump(tester, CohortCard(cohort: sampleCohort(), enrolled: true));

      expect(find.text('Summer Bootcamp'), findsOneWidget);
      expect(find.text('Зуны бүтээлч кэмп'), findsNothing);
    });

    testWidgets('English with no English title: the Mongolian one', (
      tester,
    ) async {
      ContentLanguage.prefersEnglish = true;
      await pump(
        tester,
        CohortCard(
          cohort: sampleCohort(
            course: const CohortCourse(
              id: 6,
              slug: 'summer-bootcamp-2027',
              title: LocalizedText(mn: 'Зуны бүтээлч кэмп'),
            ),
          ),
          enrolled: true,
        ),
      );

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
    });
  });

  group('contract card', () {
    StudentContract contract({String? titleEn}) => StudentContract(
      status: StudentContractStatus.signed,
      course: ContractCourse(
        titleMn: 'Хиймэл оюуны үндэс',
        titleEn: titleEn,
        level: 'adult',
      ),
      cohort: const ContractCohort(name: 'Cohort A'),
    );

    testWidgets('Mongolian: the Mongolian course title, as before', (
      tester,
    ) async {
      await pump(
        tester,
        ContractCard(contract: contract(titleEn: 'AI Basics')),
      );

      expect(find.text('Хиймэл оюуны үндэс'), findsOneWidget);
      expect(find.text('AI Basics'), findsNothing);
    });

    testWidgets('English: the English course title', (tester) async {
      ContentLanguage.prefersEnglish = true;
      await pump(
        tester,
        ContractCard(contract: contract(titleEn: 'AI Basics')),
      );

      expect(find.text('AI Basics'), findsOneWidget);
      expect(find.text('Хиймэл оюуны үндэс'), findsNothing);
    });

    testWidgets('English with a null or blank English title: the Mongolian '
        'one', (tester) async {
      ContentLanguage.prefersEnglish = true;
      for (final titleEn in [null, '  ']) {
        await pump(tester, ContractCard(contract: contract(titleEn: titleEn)));
        expect(
          find.text('Хиймэл оюуны үндэс'),
          findsOneWidget,
          reason: '$titleEn',
        );
      }
    });
  });
}
