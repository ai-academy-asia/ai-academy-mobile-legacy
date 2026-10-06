import '../domain/payment_plan.dart';

/// **TEMPORARY UI FIXTURES — not backend data.** (Issue #196)
///
/// The Adult Payment screen was built from three Figma references before any
/// usable `GET /me/ledger` sample with installments existed (the only
/// verified response had `"installments": []`). These are the references'
/// own figures, typed in by hand so the screen can be built, reviewed and
/// tested. They describe no real student and must never be shown as one:
/// release builds never open the screen with them (see `HomeScreen`), and
/// they go away once `/me/ledger` is mapped into [PaymentPlan].
///
/// Each fixture carries the "today" its reference was drawn on, so the
/// derived states (next with days left, overdue, paid off) match the
/// reference whatever the real date is.
///
/// **Visual values, kept verbatim** (Figma is the source of truth here):
///
///  * The rows' date labels are each reference's own text, even where no
///    real calendar agrees ("Бя, 3 сарын 12" is no Saturday in a year whose
///    8 March is a Sunday; "Ня" and "Ням" both appear; the fully-paid
///    reference repeats "Ня, 3 сарын 8" four times). The underlying due
///    dates are the references' days of March 2026 — 8, 12, 17, 22 — and
///    serve only to work out each row's state.
///  * The progress fill is the bar each reference draws — 114 of its 361
///    points — not 500,000 ÷ 2,000,000.
abstract final class PaymentPlanUiFixtures {
  /// The fill references 1 and 3 draw: 114 of the bar's 361 points.
  static const double _drawnFill = 114 / 361;

  /// The labels references 1 and 3 print.
  static const List<String> _labels = [
    'Ня, 3 сарын 8',
    'Бя, 3 сарын 12',
    'Да, 3 сарын 17',
    'Ням, 3 сарын 22',
  ];

  /// The label reference 2 prints on all four rows.
  static const List<String> _paidOffLabels = [
    'Ня, 3 сарын 8',
    'Ня, 3 сарын 8',
    'Ня, 3 сарын 8',
    'Ня, 3 сарын 8',
  ];

  /// Four installments of 500,000₮, as every reference draws them.
  static List<PaymentInstallment> _installments({
    required int paidCount,
    List<String> labels = _labels,
  }) => [
    for (final (i, day) in const [8, 12, 17, 22].indexed)
      PaymentInstallment(
        number: i + 1,
        dueDate: DateTime(2026, 3, day),
        dueDateLabel: labels[i],
        amount: 500000,
        paid: i < paidCount,
      ),
  ];

  /// Reference 1 — partly paid: the first installment paid, the second due
  /// in 3 days.
  static final PaymentPlanFixture partlyPaid = PaymentPlanFixture(
    plan: PaymentPlan(
      totalDue: 2000000,
      totalPaid: 500000,
      balance: 1500000,
      paidFraction: _drawnFill,
      installments: _installments(paidCount: 1),
    ),
    today: DateTime(2026, 3, 9),
  );

  /// Reference 2 — fully paid: every installment paid, nothing owed.
  static final PaymentPlanFixture paidOff = PaymentPlanFixture(
    plan: PaymentPlan(
      totalDue: 2000000,
      totalPaid: 2000000,
      balance: 0,
      paidFraction: 1,
      installments: _installments(paidCount: 4, labels: _paidOffLabels),
    ),
    today: DateTime(2026, 3, 23),
  );

  /// Reference 3 — overdue: the first installment paid, the second past its
  /// due date, and the summary naming the course.
  static final PaymentPlanFixture overdue = PaymentPlanFixture(
    plan: PaymentPlan(
      courseTitle: 'AI Engineer',
      totalDue: 2000000,
      totalPaid: 500000,
      balance: 1500000,
      paidFraction: _drawnFill,
      installments: _installments(paidCount: 1),
    ),
    today: DateTime(2026, 3, 13),
  );
}

/// A fixture plan and the day it is shown on.
class PaymentPlanFixture {
  const PaymentPlanFixture({required this.plan, required this.today});

  final PaymentPlan plan;
  final DateTime today;
}
