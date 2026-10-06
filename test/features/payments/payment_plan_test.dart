import 'package:aia_mobile/features/home/presentation/payment_strings.dart';
import 'package:aia_mobile/features/payments/data/payment_plan_ui_fixtures.dart';
import 'package:aia_mobile/features/payments/domain/payment_plan.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentPlan planOf(List<(int day, bool paid)> installments) => PaymentPlan(
  totalDue: 0,
  totalPaid: 0,
  balance: 0,
  paidFraction: 0,
  installments: [
    for (final (i, (day, paid)) in installments.indexed)
      PaymentInstallment(
        number: i + 1,
        dueDate: DateTime(2026, 3, day),
        dueDateLabel: '$day',
        amount: 1,
        paid: paid,
      ),
  ],
);

void main() {
  group('PaymentPlan.statusesOn', () {
    final plan = planOf([(8, true), (12, false), (17, false), (22, false)]);

    test('ticks paid ones, counts down to the first unpaid one and leaves '
        'the rest upcoming', () {
      expect(plan.statusesOn(DateTime(2026, 3, 9)), const [
        InstallmentStatus.paid(),
        InstallmentStatus.next(3),
        InstallmentStatus.upcoming(),
        InstallmentStatus.upcoming(),
      ]);
    });

    test('an installment due today is next with 0 days, whatever the hour', () {
      expect(
        plan.statusesOn(DateTime(2026, 3, 12, 23, 59))[1],
        const InstallmentStatus.next(0),
      );
    });

    test('the first unpaid one turns overdue the day after it fell due', () {
      expect(plan.statusesOn(DateTime(2026, 3, 13)), const [
        InstallmentStatus.paid(),
        InstallmentStatus.overdue(),
        InstallmentStatus.upcoming(),
        InstallmentStatus.upcoming(),
      ]);
    });

    test('only the first unpaid one can be overdue', () {
      expect(plan.statusesOn(DateTime(2026, 4, 1)), const [
        InstallmentStatus.paid(),
        InstallmentStatus.overdue(),
        InstallmentStatus.upcoming(),
        InstallmentStatus.upcoming(),
      ]);
    });

    test('a fully paid plan is all ticks', () {
      expect(
        planOf([(8, true), (12, true)]).statusesOn(DateTime(2026, 3, 1)),
        const [InstallmentStatus.paid(), InstallmentStatus.paid()],
      );
    });
  });

  test('unpaidCount counts the unpaid installments', () {
    expect(planOf([(8, true), (12, false), (17, false)]).unpaidCount, 2);
  });

  test('isPaidOff follows the balance', () {
    PaymentPlan withBalance(num balance) => PaymentPlan(
      totalDue: 10,
      totalPaid: 10,
      balance: balance,
      paidFraction: 1,
      installments: const [],
    );
    expect(withBalance(0).isPaidOff, isTrue);
    expect(withBalance(-5).isPaidOff, isTrue);
    expect(withBalance(1).isPaidOff, isFalse);
  });

  group('PaymentStrings', () {
    test('amount groups thousands and puts the sign after', () {
      expect(PaymentStrings.amount(2000000), '2,000,000₮');
      expect(PaymentStrings.amount(500000), '500,000₮');
      expect(PaymentStrings.amount(999), '999₮');
      expect(PaymentStrings.amount(0), '0₮');
      expect(PaymentStrings.amount(-1500), '-1,500₮');
    });

    test('totalLabel is led by the course when there is one', () {
      expect(PaymentStrings.totalLabel(null), 'Нийт сургалтын төлбөр');
      expect(PaymentStrings.totalLabel(''), 'Нийт сургалтын төлбөр');
      expect(
        PaymentStrings.totalLabel('AI Engineer'),
        'AI Engineer Нийт сургалтын төлбөр',
      );
    });
  });

  group('UI fixtures reproduce their references', () {
    List<InstallmentKind> kinds(PaymentPlanFixture f) => [
      for (final s in f.plan.statusesOn(f.today)) s.kind,
    ];

    test('1 — partly paid: one paid, next in 3 days, two upcoming', () {
      final f = PaymentPlanUiFixtures.partlyPaid;
      expect(f.plan.statusesOn(f.today)[1], const InstallmentStatus.next(3));
      expect(kinds(f), [
        InstallmentKind.paid,
        InstallmentKind.next,
        InstallmentKind.upcoming,
        InstallmentKind.upcoming,
      ]);
      expect(f.plan.isPaidOff, isFalse);
      expect(f.plan.unpaidCount, 3);
      expect(f.plan.courseTitle, isNull);
      expect(f.plan.paidFraction, 114 / 361);
    });

    test('2 — paid off: four ticks, nothing owed, a full bar', () {
      final f = PaymentPlanUiFixtures.paidOff;
      expect(kinds(f), List.filled(4, InstallmentKind.paid));
      expect(f.plan.isPaidOff, isTrue);
      expect(f.plan.paidFraction, 1);
      expect([
        for (final i in f.plan.installments) i.dueDateLabel,
      ], List.filled(4, 'Ня, 3 сарын 8'));
    });

    test('3 — overdue: the second installment overdue, the course named', () {
      final f = PaymentPlanUiFixtures.overdue;
      expect(kinds(f), [
        InstallmentKind.paid,
        InstallmentKind.overdue,
        InstallmentKind.upcoming,
        InstallmentKind.upcoming,
      ]);
      expect(f.plan.courseTitle, 'AI Engineer');
    });

    test('the date labels are the references\' own text, verbatim', () {
      expect(
        [
          for (final i in PaymentPlanUiFixtures.partlyPaid.plan.installments)
            i.dueDateLabel,
        ],
        [
          'Ня, 3 сарын 8',
          'Бя, 3 сарын 12',
          'Да, 3 сарын 17',
          'Ням, 3 сарын 22',
        ],
      );
    });
  });
}
