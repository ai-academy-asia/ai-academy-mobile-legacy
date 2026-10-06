/// One enrollment's tuition and how it is split into installments — what the
/// Adult Payment screen ("Төлбөр") draws.
///
/// **Not tied to any response shape.** `GET /me/ledger` is the intended source
/// (`mobile_api_v1_1.md` §7: "per enrollment: due/paid/balance +
/// installments"), and its verified fields map straight onto [totalDue]
/// (`total_due`), [totalPaid] (`total_paid`), [balance] (`balance`) and
/// [courseTitle] (`course.title`). The installments do not: the only verified
/// response had `"installments": []`, so no installment field is confirmed
/// yet and nothing here assumes one. Until a real sample arrives the screen is
/// fed only the temporary UI fixtures (`PaymentPlanUiFixtures`), and a
/// `/me/ledger` mapping is a later, separate step that fills this same model
/// — see `docs/ai/DATA_AND_API.md` §9.
class PaymentPlan {
  const PaymentPlan({
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.paidFraction,
    required this.installments,
    this.courseTitle,
  });

  /// The course the plan is for, when the summary names it — the overdue
  /// reference reads "AI Engineer Нийт сургалтын төлбөр". Null leaves the
  /// line as the other two references draw it: "Нийт сургалтын төлбөр".
  final String? courseTitle;

  /// The whole tuition, in tögrög.
  final num totalDue;

  /// What has been paid so far.
  final num totalPaid;

  /// What is still owed. Kept as its own figure rather than worked out from
  /// the two above: the ledger sends it, and a discount or a refund would make
  /// a client-side subtraction wrong.
  final num balance;

  /// Every installment, in the order they fall due.
  final List<PaymentInstallment> installments;

  /// Nothing left to pay — the "Төлөгдөж дуссан" state.
  bool get isPaidOff => balance <= 0;

  /// How far the progress bar is filled, 0 to 1 — given by the plan's
  /// source, not worked out here.
  ///
  /// The obvious reading, [totalPaid] ÷ [totalDue], is not what the Figma
  /// reference draws (500,000 of 2,000,000 fills about 32% of its bar, not
  /// 25%), and which rule the real screen follows — that share, installments
  /// paid, or something the backend sends — is not decided. So the source
  /// says: the UI fixtures give the reference's own fill, and the
  /// `/me/ledger` mapping will give whatever is confirmed then.
  final double paidFraction;

  /// How many installments are still unpaid — the N in "N-нь төлөлт дутуу".
  int get unpaidCount =>
      installments.where((installment) => !installment.paid).length;

  /// How each installment is drawn on [today], in the same order as
  /// [installments].
  ///
  /// The rule the three references draw: a paid installment is ticked; the
  /// first unpaid one is the one the student is working towards — "next",
  /// with its days left, or "overdue" once its due date has passed; every
  /// later unpaid one is plain "upcoming". Whether the backend sends these
  /// states itself, or only the dates and paid flags this works them out
  /// from, is not known yet: confirm it against the first real `/me/ledger`
  /// sample.
  List<InstallmentStatus> statusesOn(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final statuses = <InstallmentStatus>[];
    var nextFound = false;
    for (final installment in installments) {
      if (installment.paid) {
        statuses.add(const InstallmentStatus.paid());
      } else if (nextFound) {
        statuses.add(const InstallmentStatus.upcoming());
      } else {
        nextFound = true;
        final due = DateTime(
          installment.dueDate.year,
          installment.dueDate.month,
          installment.dueDate.day,
        );
        statuses.add(
          due.isBefore(day)
              ? const InstallmentStatus.overdue()
              // Rounded, so a daylight-saving shift between the two local
              // midnights cannot lose a day.
              : InstallmentStatus.next(
                  (due.difference(day).inHours / 24).round(),
                ),
        );
      }
    }
    return statuses;
  }
}

/// One scheduled payment.
class PaymentInstallment {
  const PaymentInstallment({
    required this.number,
    required this.dueDate,
    required this.dueDateLabel,
    required this.amount,
    required this.paid,
  });

  /// 1-based position in the plan — the "Төлөлт N" on its badge.
  final int number;

  /// The local calendar date it falls due — what its state is worked out
  /// from.
  final DateTime dueDate;

  /// The date as its row prints it, e.g. "Ня, 3 сарын 8" — supplied
  /// already formatted, as `CourseModule.scheduleLabel` is. The Figma
  /// references' labels are placeholders that follow no single format
  /// ("Ня" and "Ням" both appear) and match no real calendar, so the UI
  /// fixtures carry them verbatim; the real format is settled with the
  /// `/me/ledger` mapping.
  final String dueDateLabel;

  /// In tögrög.
  final num amount;

  final bool paid;
}

/// How one installment is drawn. See [PaymentPlan.statusesOn].
class InstallmentStatus {
  const InstallmentStatus.paid() : kind = InstallmentKind.paid, daysLeft = null;

  /// The first unpaid installment, due in [daysLeft] days (0 = today).
  const InstallmentStatus.next(int this.daysLeft) : kind = InstallmentKind.next;

  /// The first unpaid installment, past its due date.
  const InstallmentStatus.overdue()
    : kind = InstallmentKind.overdue,
      daysLeft = null;

  /// An unpaid installment after the next one.
  const InstallmentStatus.upcoming()
    : kind = InstallmentKind.upcoming,
      daysLeft = null;

  final InstallmentKind kind;

  /// Only for [InstallmentKind.next].
  final int? daysLeft;

  @override
  bool operator ==(Object other) =>
      other is InstallmentStatus &&
      other.kind == kind &&
      other.daysLeft == daysLeft;

  @override
  int get hashCode => Object.hash(kind, daysLeft);

  @override
  String toString() => 'InstallmentStatus($kind, $daysLeft)';
}

enum InstallmentKind { paid, next, overdue, upcoming }
