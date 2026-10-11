import 'dart:async';
import 'dart:typed_data';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_form_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_signing_controller.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// The E-Contract form step (Issue #314), against the hand-driven fake — no
/// backend is reached, and every test checks that neither the preview nor
/// the sign endpoint was asked for. Test values only.
void main() {
  ContractRules rules({
    bool guardian = false,
    bool finalDate = false,
    DateTime? max,
    bool noMax = false,
  }) => ContractRules(
    guardianRequired: guardian,
    finalPaymentDateRequired: finalDate,
    finalPaymentDateMin: DateTime(2026, 10, 10),
    finalPaymentDateMax: noMax ? null : (max ?? DateTime(2026, 10, 30)),
  );

  /// Prefilled as the backend prefills a pending form: names, phone,
  /// e-mail — no register or address.
  const prefilled = ContractForm(
    lastName: 'Тест',
    firstName: 'Сурагч',
    phone: '00000000',
    email: 'student@example.test',
  );

  ContractDetail detail({
    ContractRules? withRules,
    ContractForm form = prefilled,
    bool canSign = true,
    StudentContractStatus status = StudentContractStatus.pending,
  }) => ContractDetail(
    contract: StudentContract(
      id: '12',
      status: status,
      canSign: canSign,
      canView: true,
      isCurrent: true,
    ),
    form: form,
    rules: withRules ?? rules(),
    finance: const ContractFinance(
      totalDue: 1000000,
      totalPaid: 0,
      balance: 1000000,
      discountPercent: 0,
      currency: 'MNT',
    ),
    document: const ContractDocument(
      format: 'pdf',
      preview: '/me/contracts/12/preview',
    ),
  );

  late FakeContractRepository repository;
  late List<ContractSigningController> continued;

  setUp(() {
    repository = FakeContractRepository(detail: detail());
    continued = [];
  });

  /// Nothing in this step may reach the preview or sign endpoints.
  void expectNoWrites() {
    expect(repository.previewCalls, isEmpty);
    expect(repository.signCalls, isEmpty);
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    ContractSigningController? controller,
  }) async {
    useLogicalViewport(tester, const Size(393, 1800));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContractFormScreen(
          contractId: '12',
          repository: repository,
          controller: controller,
          onContinue: (_, c) => continued.add(c),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(ContractFormField f) =>
      find.widgetWithText(TextField, ContractStrings.fieldLabel(f));

  String textOf(WidgetTester tester, ContractFormField f) =>
      tester.widget<TextField>(field(f)).controller!.text;

  Future<void> enter(WidgetTester tester, ContractFormField f, String value) =>
      tester.enterText(field(f), value);

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
  }

  String error(ContractFormField f, ContractFieldReason reason) =>
      ContractStrings.fieldError(f, reason);

  Future<void> fillStudent(WidgetTester tester) async {
    await enter(tester, ContractFormField.register, 'уб12345678');
    await enter(tester, ContractFormField.address, 'Улаанбаатар');
  }

  group('loading and failure', () {
    testWidgets('shows a loader until the detail answers', (tester) async {
      repository.detailGate = Completer<void>();
      useLogicalViewport(tester, const Size(393, 1800));
      await tester.pumpWidget(
        MaterialApp(
          home: ContractFormScreen(contractId: '12', repository: repository),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(repository.detailCalls, ['12']);

      repository.detailGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(field(ContractFormField.lastName), findsOneWidget);
    });

    testWidgets('a failed load shows its line and retries', (tester) async {
      repository.detailFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      await pumpForm(tester);

      expect(find.text(ProfileStrings.networkError), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      repository.detailFailure = null;
      await tester.tap(find.text(ContractStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.detailCalls, ['12', '12']);
      expect(field(ContractFormField.lastName), findsOneWidget);
      expectNoWrites();
    });
  });

  group('adult form', () {
    testWidgets('shows the student fields prefilled from detail.form, and '
        'no guardian or date field', (tester) async {
      await pumpForm(tester);

      expect(textOf(tester, ContractFormField.lastName), 'Тест');
      expect(textOf(tester, ContractFormField.firstName), 'Сурагч');
      expect(textOf(tester, ContractFormField.phone), '00000000');
      expect(textOf(tester, ContractFormField.email), 'student@example.test');
      // Not prefilled by the backend, and not invented here.
      expect(textOf(tester, ContractFormField.register), isEmpty);
      expect(textOf(tester, ContractFormField.address), isEmpty);

      for (final f in [
        ContractFormField.guardianRelation,
        ContractFormField.guardianLastName,
        ContractFormField.guardianFirstName,
        ContractFormField.guardianRegister,
        ContractFormField.finalPaymentDate,
      ]) {
        expect(field(f), findsNothing, reason: f.name);
      }
      expect(find.text(ContractStrings.formGuardianSection), findsNothing);
      expect(find.text(ContractStrings.formPaymentSection), findsNothing);
    });

    testWidgets('no error is shown before Continue', (tester) async {
      await pumpForm(tester);
      expect(
        find.text(
          error(ContractFormField.register, ContractFieldReason.required),
        ),
        findsNothing,
      );
    });

    testWidgets('Continue with required fields missing shows their errors '
        'and does not advance', (tester) async {
      await pumpForm(tester);
      await tapContinue(tester);

      // register and address — the two the backend does not prefill.
      expect(
        find.text(
          ContractStrings.fieldError(
            ContractFormField.register,
            ContractFieldReason.required,
          ),
        ),
        findsNWidgets(2),
      );
      expect(continued, isEmpty);
      expectNoWrites();
    });

    testWidgets('format errors come from the validator, per field', (
      tester,
    ) async {
      await pumpForm(tester);
      await fillStudent(tester);
      await enter(tester, ContractFormField.lastName, 'Test');
      await enter(tester, ContractFormField.phone, '1234');
      await enter(tester, ContractFormField.email, 'not-an-email');
      await tapContinue(tester);

      expect(
        find.text(
          error(ContractFormField.lastName, ContractFieldReason.cyrillicOnly),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          error(ContractFormField.phone, ContractFieldReason.invalidFormat),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          error(ContractFormField.email, ContractFieldReason.invalidFormat),
        ),
        findsOneWidget,
      );
      expect(continued, isEmpty);

      // Errors follow the form once shown.
      await enter(tester, ContractFormField.lastName, 'Тест');
      await tester.pump();
      expect(
        find.text(
          error(ContractFormField.lastName, ContractFieldReason.cyrillicOnly),
        ),
        findsNothing,
      );
    });

    testWidgets('a valid form advances once, with the edited form on the '
        'controller, and calls no endpoint', (tester) async {
      await pumpForm(tester);
      await fillStudent(tester);
      await tapContinue(tester);

      expect(continued, hasLength(1));
      final form = continued.single.form;
      expect(form.register, 'уб12345678');
      expect(form.address, 'Улаанбаатар');
      expect(form.lastName, 'Тест');
      expect(continued.single.fieldErrors, isEmpty);
      expect(repository.detailCalls, ['12']);
      expectNoWrites();
    });
  });

  group('junior form', () {
    setUp(() => repository.detail = detail(withRules: rules(guardian: true)));

    testWidgets('shows the four guardian fields and requires them', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.text(ContractStrings.formGuardianSection), findsOneWidget);
      for (final f in [
        ContractFormField.guardianRelation,
        ContractFormField.guardianLastName,
        ContractFormField.guardianFirstName,
        ContractFormField.guardianRegister,
      ]) {
        expect(field(f), findsOneWidget, reason: f.name);
      }

      await fillStudent(tester);
      await tapContinue(tester);

      expect(
        find.text(
          error(
            ContractFormField.guardianRelation,
            ContractFieldReason.required,
          ),
        ),
        findsNWidgets(4),
      );
      expect(continued, isEmpty);

      await enter(tester, ContractFormField.guardianRelation, 'Ээж');
      await enter(tester, ContractFormField.guardianLastName, 'Тест');
      await enter(tester, ContractFormField.guardianFirstName, 'Асран');
      await enter(tester, ContractFormField.guardianRegister, 'УБ87654321');
      await tapContinue(tester);

      expect(continued, hasLength(1));
      expectNoWrites();
    });
  });

  group('final payment date', () {
    testWidgets('shown only when required, read-only, and picked from a '
        'calendar bounded by min and max', (tester) async {
      repository.detail = detail(withRules: rules(finalDate: true));
      await pumpForm(tester);

      expect(find.text(ContractStrings.formPaymentSection), findsOneWidget);
      final dateField = tester.widget<TextField>(
        field(ContractFormField.finalPaymentDate),
      );
      expect(dateField.readOnly, isTrue);

      await fillStudent(tester);
      await tapContinue(tester);
      expect(
        find.text(
          error(
            ContractFormField.finalPaymentDate,
            ContractFieldReason.required,
          ),
        ),
        findsOneWidget,
      );
      expect(continued, isEmpty);

      await tester.tap(field(ContractFormField.finalPaymentDate));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2026, 10, 10));
      expect(dialog.lastDate, DateTime(2026, 10, 30));
      expect(dialog.initialEntryMode, DatePickerEntryMode.calendarOnly);

      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(textOf(tester, ContractFormField.finalPaymentDate), '2026-10-20');
      await tapContinue(tester);
      expect(continued, hasLength(1));
      expect(continued.single.form.finalPaymentDate, '2026-10-20');
      expectNoWrites();
    });

    testWidgets('with no max, the calendar still opens from the min', (
      tester,
    ) async {
      repository.detail = detail(
        withRules: rules(finalDate: true, noMax: true),
      );
      await pumpForm(tester);

      await tester.tap(field(ContractFormField.finalPaymentDate));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2026, 10, 10));
      expect(dialog.lastDate.isAfter(DateTime(2026, 10, 10)), isTrue);
    });

    testWidgets('a prefilled date outside the range is flagged, not '
        'silently changed', (tester) async {
      repository.detail = detail(
        withRules: rules(finalDate: true),
        form: const ContractForm(
          lastName: 'Тест',
          firstName: 'Сурагч',
          register: 'УБ12345678',
          phone: '00000000',
          address: 'Улаанбаатар',
          finalPaymentDate: '2026-12-01',
        ),
      );
      await pumpForm(tester);
      await tapContinue(tester);

      expect(textOf(tester, ContractFormField.finalPaymentDate), '2026-12-01');
      expect(
        find.text(
          error(
            ContractFormField.finalPaymentDate,
            ContractFieldReason.outOfRange,
          ),
        ),
        findsOneWidget,
      );
      expect(continued, isEmpty);
    });
  });

  group('read-only', () {
    for (final (name, d) in [
      ('can_sign false', detail(canSign: false)),
      ('signed', detail(canSign: false, status: StudentContractStatus.signed)),
    ]) {
      testWidgets('$name: fields disabled, Continue disabled', (tester) async {
        repository.detail = d;
        await pumpForm(tester);

        expect(find.text(ContractStrings.formReadOnly), findsOneWidget);
        for (final text in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(text.enabled, isFalse);
        }
        expect(
          tester.widget<AppButton>(find.byType(AppButton)).onPressed,
          isNull,
        );
        await tapContinue(tester);
        expect(continued, isEmpty);
        expectNoWrites();
      });
    }
  });

  group('junior phone (review of #315)', () {
    const guardianPhone = 'Асран хамгаалагчийн утасны дугаар';

    testWidgets('a junior form shows the backend phone as the guardian\'s, '
        'in the guardian section', (tester) async {
      repository.detail = detail(withRules: rules(guardian: true));
      await pumpForm(tester);

      final phone = find.widgetWithText(TextField, guardianPhone);
      expect(phone, findsOneWidget);
      expect(field(ContractFormField.phone), findsNothing);
      // Still the backend's `phone`, prefilled as sent.
      expect(tester.widget<TextField>(phone).controller!.text, '00000000');
      expect(
        tester.getTopLeft(phone).dy,
        greaterThan(
          tester.getTopLeft(find.text(ContractStrings.formGuardianSection)).dy,
        ),
      );

      await tester.enterText(phone, '99112233');
      expect(repository.detailCalls, ['12']);
      await fillStudent(tester);
      await enter(tester, ContractFormField.guardianRelation, 'Ээж');
      await enter(tester, ContractFormField.guardianLastName, 'Тест');
      await enter(tester, ContractFormField.guardianFirstName, 'Асран');
      await enter(tester, ContractFormField.guardianRegister, 'УБ87654321');
      await tapContinue(tester);

      expect(continued, hasLength(1));
      expect(continued.single.form.phone, '99112233');
      expect(
        continued.single.form.toJson().containsKey('guardian_phone'),
        isFalse,
      );
      expectNoWrites();
    });

    testWidgets('an adult form keeps the plain phone label', (tester) async {
      await pumpForm(tester);
      expect(field(ContractFormField.phone), findsOneWidget);
      expect(find.widgetWithText(TextField, guardianPhone), findsNothing);
    });
  });

  group('errors on fields the form does not draw (review of #315)', () {
    for (final (name, form) in [
      (
        'a guardian field, adult course',
        const ContractForm(
          lastName: 'Тест',
          firstName: 'Сурагч',
          phone: '00000000',
          guardianLastName: 'Smith',
        ),
      ),
      (
        'the final payment date, not required',
        const ContractForm(
          lastName: 'Тест',
          firstName: 'Сурагч',
          phone: '00000000',
          finalPaymentDate: '2020-01-01',
        ),
      ),
    ]) {
      testWidgets('$name: Continue is blocked with a visible general error', (
        tester,
      ) async {
        repository.detail = detail(form: form);
        await pumpForm(tester);

        expect(find.text(ContractStrings.formHiddenErrors), findsNothing);
        await fillStudent(tester);
        await tapContinue(tester);

        expect(find.text(ContractStrings.formHiddenErrors), findsOneWidget);
        // No visible field is at fault, and none is drawn for the hidden one.
        expect(field(ContractFormField.guardianLastName), findsNothing);
        expect(field(ContractFormField.finalPaymentDate), findsNothing);
        expect(continued, isEmpty);

        // Pressing again changes nothing: the form cannot pass from here.
        await tapContinue(tester);
        expect(continued, isEmpty);
        expectNoWrites();
      });
    }

    testWidgets('visible field errors still show beside the general line', (
      tester,
    ) async {
      repository.detail = detail(
        form: const ContractForm(
          lastName: 'Тест',
          firstName: 'Сурагч',
          phone: '00000000',
          guardianLastName: 'Smith',
        ),
      );
      await pumpForm(tester);
      await tapContinue(tester);

      expect(find.text(ContractStrings.formHiddenErrors), findsOneWidget);
      expect(
        find.text(
          error(ContractFormField.register, ContractFieldReason.required),
        ),
        findsNWidgets(2),
      );
      expect(continued, isEmpty);
    });
  });

  group('inconsistent payment-date rules (review of #315)', () {
    testWidgets('max before min: explained, no picker, Continue disabled, '
        'rules and date left as sent', (tester) async {
      repository.detail = detail(
        withRules: rules(finalDate: true, max: DateTime(2026, 10, 5)),
      );
      await pumpForm(tester);

      // Shown at once — not the student's error to discover.
      expect(find.text(ContractStrings.formDateRulesInvalid), findsOneWidget);
      final date = field(ContractFormField.finalPaymentDate);
      expect(tester.widget<TextField>(date).enabled, isFalse);

      await tester.tap(date, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);

      await fillStudent(tester);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      await tapContinue(tester);
      expect(continued, isEmpty);

      expect(textOf(tester, ContractFormField.finalPaymentDate), isEmpty);
      expect(
        repository.detail!.rules.finalPaymentDateMax,
        DateTime(2026, 10, 5),
      );
      expectNoWrites();
    });

    testWidgets('max equal to min is consistent: one pickable day', (
      tester,
    ) async {
      repository.detail = detail(
        withRules: rules(finalDate: true, max: DateTime(2026, 10, 10)),
      );
      await pumpForm(tester);

      expect(find.text(ContractStrings.formDateRulesInvalid), findsNothing);
      await tester.tap(field(ContractFormField.finalPaymentDate));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2026, 10, 10));
      expect(dialog.lastDate, DateTime(2026, 10, 10));
    });
  });

  group('server invalid_fields', () {
    testWidgets('a shared controller is not reloaded, and the server\'s '
        'reasons land on the same fields until edited', (tester) async {
      final controller = ContractSigningController(
        contractId: '12',
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();

      repository.signFailure = const ContractFailure(
        ContractFailureKind.invalidFields,
        fieldErrors: {
          'register': ContractFieldReason.invalidFormat,
          'some_new_field': ContractFieldReason.required,
        },
      );
      controller
        ..updateField(ContractFormField.register, 'УБ12345678')
        ..updateField(ContractFormField.address, 'Улаанбаатар');
      // Against the fake: a later step's refused sign, coming back here.
      await controller.sign(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        agreed: true,
      );
      expect(repository.signCalls, hasLength(1));

      await pumpForm(tester, controller: controller);

      expect(repository.detailCalls, ['12']);
      expect(textOf(tester, ContractFormField.register), 'УБ12345678');
      expect(
        find.text(
          error(ContractFormField.register, ContractFieldReason.invalidFormat),
        ),
        findsOneWidget,
      );
      expect(find.text(ContractStrings.formUnmatchedErrors), findsOneWidget);

      await enter(tester, ContractFormField.register, 'УБ12345679');
      await tester.pump();
      expect(
        find.text(
          error(ContractFormField.register, ContractFieldReason.invalidFormat),
        ),
        findsNothing,
      );
      expect(repository.previewCalls, isEmpty);
    });
  });
}
