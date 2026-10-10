import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../data/http_contract_repository.dart';
import '../domain/contract_repository.dart';
import 'contract_list_controller.dart';
import 'contract_strings.dart';

/// The student's e-contracts (Issue #294), read from `GET /me/contracts`.
///
/// Reached from the "E-Contract" row of both student Profiles — Adult and
/// Junior — through [ContractScreen.open]. A Junior student is a student in
/// kids mode on the same student token and `/me/...` endpoints, so both see
/// the same screen.
///
/// **No Figma frame draws it.** It is the Certificate and Notification
/// screens' skeleton — the back button with the title centred on its row, a
/// loader, and a centred line with a retry on failure — and draws only what
/// the verified response supports:
///
///  * `{"contracts": []}` — [ContractStrings.empty];
///  * one or more contracts — [ContractStrings.notShownYet]. No item field
///    beyond `id` is documented, so no title, course, status or date is
///    drawn, and nothing opens a contract: the detail, preview, sign and
///    download endpoints' responses are not documented (`BACKEND GAP`).
class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key, this.repository});

  /// Defaults to the real API. Injected in tests.
  final ContractRepository? repository;

  /// Pushes the screen over [context]'s navigator — what both Profiles'
  /// "E-Contract" rows do.
  static Future<void> open(
    BuildContext context, {
    ContractRepository? repository,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContractScreen(repository: repository),
    ),
  );

  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  late final ContractListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ContractListController(
      repository: widget.repository ?? HttpContractRepository(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surface,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _body(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_controller.hasLoadedOnce || _controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final message = _controller.errorMessage;
    if (message != null) {
      return _Message(
        message: message,
        action: TextButton(
          onPressed: _controller.load,
          child: const Text(ContractStrings.retry),
        ),
      );
    }
    return _Message(
      message: _controller.contracts.isEmpty
          ? ContractStrings.empty
          : ContractStrings.notShownYet,
    );
  }
}

/// The back button with "E-Contract" centred on its row — the Certificate
/// and Notification screens' header.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const CourseLearningBackButton(icon: AppIcons.arrowLeft),
        Positioned.fill(
          top: _backButtonTop,
          child: Center(
            child: Text(
              ContractStrings.title,
              style: _titleStyle.copyWith(color: context.palette.textTitle),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: AppDimens.fieldGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// `CourseLearningBackButton`'s own inset above the circle.
const double _backButtonTop = 12;

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);
