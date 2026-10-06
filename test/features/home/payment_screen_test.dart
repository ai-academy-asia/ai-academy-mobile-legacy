import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_amount_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_previews.dart';
import 'package:aia_mobile/features/home/presentation/payment_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_pill_button.dart';
import 'package:aia_mobile/features/payments/data/payment_plan_ui_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pushes [screen] over a plain route, so the back button has somewhere to
/// return to.
Future<void> pumpPayment(WidgetTester tester, PaymentScreen screen) async {
  tester.view
    ..physicalSize = const Size(393, 946)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

HomePillButton payButton(WidgetTester tester) => tester.widget(
  find.widgetWithText(HomePillButton, PaymentStrings.payAction),
);

double progressFill(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(
      find.descendant(
        of: find.byType(PaymentScreen),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .widthFactor!;

void main() {
  testWidgets('reference 1 — partly paid', (tester) async {
    await pumpPayment(tester, PaymentPreviews.partlyPaid.screen());

    expect(find.text(PaymentStrings.title), findsOneWidget);
    expect(find.text(PaymentStrings.totalLabel(null)), findsOneWidget);
    expect(find.text('2,000,000₮'), findsOneWidget);
    expect(find.text(PaymentStrings.paid), findsOneWidget);
    expect(find.text(PaymentStrings.unpaidInstallments(3)), findsOneWidget);
    expect(find.text('500,000₮'), findsNWidgets(5));
    expect(find.text('1,500,000₮'), findsOneWidget);
    expect(find.text(PaymentStrings.paidOff), findsNothing);
    expect(progressFill(tester), 114 / 361);

    expect(find.text(PaymentStrings.schedule), findsOneWidget);
    for (final label in [
      'Ня, 3 сарын 8',
      'Бя, 3 сарын 12',
      'Да, 3 сарын 17',
      'Ням, 3 сарын 22',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(PaymentStrings.dueIn(3)), findsOneWidget);
    expect(find.text(PaymentStrings.overdue), findsNothing);
    // The paid badge draws a tick; the other three their number.
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.text(PaymentStrings.installment), findsNWidgets(3));
    expect(find.byIcon(AppIcons.caretRight), findsNWidgets(4));

    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('reference 2 — paid off: the CTA is disabled', (tester) async {
    await pumpPayment(tester, PaymentPreviews.paidOff.screen());

    expect(find.text(PaymentStrings.paidOff), findsOneWidget);
    expect(find.text(PaymentStrings.paid), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.text('Ня, 3 сарын 8'), findsNWidgets(4));
    expect(find.byIcon(AppIcons.check), findsNWidgets(4));
    expect(find.text(PaymentStrings.installment), findsNothing);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('reference 3 — overdue, the course named', (tester) async {
    await pumpPayment(tester, PaymentPreviews.overdue.screen());

    expect(find.text('AI Engineer Нийт сургалтын төлбөр'), findsOneWidget);
    expect(find.text(PaymentStrings.overdue), findsOneWidget);
    expect(find.textContaining('хоног дутуу'), findsNothing);
    expect(progressFill(tester), 114 / 361);
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('the chevrons lead nowhere', (tester) async {
    await pumpPayment(tester, PaymentPreviews.partlyPaid.screen());

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(AppIcons.caretRight).at(i));
      await tester.pumpAndSettle();
    }

    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Төлбөр төлөх" opens the payment flow (Issue #198)', (
    tester,
  ) async {
    await pumpPayment(tester, PaymentPreviews.overdue.screen());

    await tester.tap(
      find.widgetWithText(HomePillButton, PaymentStrings.payAction),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaymentAmountScreen), findsOneWidget);
  });

  testWidgets('without a payFlow "Төлбөр төлөх" stays live but inert', (
    tester,
  ) async {
    final fixture = PaymentPlanUiFixtures.partlyPaid;
    await pumpPayment(
      tester,
      PaymentScreen(plan: fixture.plan, today: fixture.today),
    );

    expect(payButton(tester).onPressed, isNotNull);
    await tester.tap(
      find.widgetWithText(HomePillButton, PaymentStrings.payAction),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.byType(PaymentAmountScreen), findsNothing);
  });

  testWidgets('back returns to the previous screen', (tester) async {
    await pumpPayment(tester, PaymentPreviews.partlyPaid.screen());

    await tester.tap(find.byType(CourseLearningBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('each row reads out as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPayment(tester, PaymentPreviews.partlyPaid.screen());

    expect(
      find.bySemanticsLabel('Ня, 3 сарын 8, 500,000₮, Төлөгдсөн'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Бя, 3 сарын 12, 3 хоног дутуу, 500,000₮'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
