import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../data/http_contract_repository.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';
import 'contract_list_controller.dart';
import 'contract_strings.dart';
import 'widgets/contract_card.dart';
import 'widgets/contract_page_parts.dart';

/// The student's e-contracts (Issues #294, #312), read from
/// `GET /me/contracts` — the Figma export `e-contract1.png`.
///
/// Reached from the "E-Contract" row of both student Profiles and from the
/// Home / Junior Progress contract banner, through [ContractScreen.open]. A
/// Junior student is a student in kids mode on the same student token and
/// `/me/...` endpoints, so both see the same screen.
///
/// **States.** A loader until the list answers; a failure's own line with a
/// retry (a failure is never shown as an empty list); `{"contracts": []}` —
/// [ContractStrings.empty], the app's own line (no frame draws an empty
/// list); otherwise one [ContractCard] per contract, newest first as the API
/// lists them, 28 under the header and 16 apart, scrolling.
///
/// **Actions.** A signed contract's "Гэрээ татах" fetches a fresh link and
/// opens it outside the app ([ContractListController.download]); a failure,
/// `not_signed` included, is a SnackBar with the existing copy — never a
/// success. A pending contract's "Гэрээ байгуулах" calls [onSign] when the
/// contract `can_sign`. The signing flow exists (Issues #314–#320), but
/// [open] passes no [onSign] on purpose: signing stays off for students
/// until a real-contract test is approved and done, so the action is drawn
/// disabled. Nothing here signs.
class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key, this.repository, this.openUrl, this.onSign});

  /// Defaults to the real API. Injected in tests.
  final ContractRepository? repository;

  /// Opens a download link. Defaults to `openExternalUrl`. Injected in
  /// tests.
  final Future<bool> Function(Uri url)? openUrl;

  /// Where a signable contract's "Гэрээ байгуулах" leads. Null — as [open]
  /// leaves it — draws the action disabled.
  final void Function(BuildContext context, StudentContract contract)? onSign;

  /// Pushes the screen over [context]'s navigator — what both Profiles'
  /// "E-Contract" rows and the contract banner do.
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
      openUrl: widget.openUrl,
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
                  const ContractHeader(),
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
      return ContractMessage(
        message: message,
        action: TextButton(
          onPressed: _controller.load,
          child: const Text(ContractStrings.retry),
        ),
      );
    }
    final contracts = _controller.contracts;
    if (contracts.isEmpty) {
      return const ContractMessage(message: ContractStrings.empty);
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        _headerToCard,
        AppDimens.screenPadding,
        AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: contracts.length,
      separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
      itemBuilder: (context, index) {
        final contract = contracts[index];
        final id = contract.id;
        final onSign = widget.onSign;
        return ContractCard(
          contract: contract,
          downloading: id != null && _controller.isDownloading(id),
          onDownload: id == null ? null : () => _download(id),
          onSign: onSign == null ? null : () => onSign(context, contract),
        );
      },
    );
  }

  Future<void> _download(String contractId) async {
    final error = await _controller.download(contractId);
    if (error == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(error)));
  }
}

/// The back button's bottom to the first card, and card to card — measured
/// off `e-contract1.png` (the Certificate list's 28 above the first card).
const double _headerToCard = 28;
const double _cardGap = 16;
