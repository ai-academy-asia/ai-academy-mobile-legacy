import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/stub_password_repository.dart';
import '../domain/password_repository.dart';
import 'reset_password_controller.dart';
import 'reset_password_strings.dart';
import 'widgets/password_requirements_panel.dart';

/// Set a new password.
///
/// Reproduces Figma `Sign in - 6` … `10` (section "Login", page "📱 - App UI"),
/// and deliberately reuses the login screen's system rather than restating it:
/// the same [AppTextField] with its dark focus and red error borders, the same
/// [AppButton], the same [AppColors] / [AppTypography] / [AppDimens] tokens, the
/// same grey page under white controls, the same scroll and keyboard handling,
/// and the same one-line message band under the form.
///
/// It differs from login in two ways the design dictates: the title sits 32pt
/// below the status bar rather than login's empty 88pt band, and it carries a
/// supporting line and the requirements panel.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.repository, this.onCompleted});

  /// Defaults to the stub — there is no confirmed endpoint yet. Injected in
  /// tests.
  final PasswordRepository? repository;

  /// Called once the password has been changed. Defaults to popping back.
  final VoidCallback? onCompleted;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final ResetPasswordController _controller;
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = ResetPasswordController(
      repository: widget.repository ?? const StubPasswordRepository(),
    );
  }

  @override
  void dispose() {
    _newFocus.dispose();
    _confirmFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final changed = await _controller.submit();
    if (!changed || !mounted) return;

    if (widget.onCompleted != null) {
      widget.onCompleted!();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(ResetPasswordStrings.success)));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // Same as login: the keyboard overlays rather than resizing, and the
        // scroll padding below keeps every field reachable regardless.
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppDimens.maxContentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.screenPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: AppDimens.resetHeadingTop),

                                Text(
                                  ResetPasswordStrings.title,
                                  style: AppTypography.heading,
                                ),
                                const SizedBox(height: AppDimens.titleToSupporting),
                                Text(
                                  ResetPasswordStrings.supporting,
                                  style: AppTypography.cardSupporting,
                                ),
                                const SizedBox(height: AppDimens.headingToForm),

                                _buildFields(),
                                const SizedBox(height: AppDimens.headingToForm),

                                PasswordRequirementsPanel(
                                  satisfied: _controller.satisfiedRequirements,
                                  strength: _controller.strength,
                                  evaluated: _controller.requirementsEvaluated,
                                ),

                                _buildMessageBand(),

                                // The reference crop shows nothing below the
                                // requirements, so the button takes the empty
                                // space at the bottom rather than crowding them.
                                const Spacer(),

                                AppButton(
                                  label: ResetPasswordStrings.submit,
                                  loading: _controller.submitting,
                                  onPressed: _controller.submitting ? null : _submit,
                                ),
                                const SizedBox(height: AppDimens.cardPadding),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFields() {
    final busy = _controller.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller.currentPassword,
          placeholder: ResetPasswordStrings.currentPassword,
          errorText: _controller.currentPasswordError,
          enabled: !busy,
          obscureText: _controller.obscureCurrent,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _newFocus.requestFocus(),
          suffix: _buildToggle(
            hidden: _controller.obscureCurrent,
            onTap: _controller.toggleObscureCurrent,
            enabled: !busy,
          ),
        ),
        const SizedBox(height: AppDimens.fieldGap),

        AppTextField(
          controller: _controller.newPassword,
          focusNode: _newFocus,
          placeholder: ResetPasswordStrings.newPassword,
          errorText: _controller.newPasswordError,
          enabled: !busy,
          obscureText: _controller.obscureNew,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _confirmFocus.requestFocus(),
          suffix: _buildToggle(
            hidden: _controller.obscureNew,
            onTap: _controller.toggleObscureNew,
            enabled: !busy,
          ),
        ),
        const SizedBox(height: AppDimens.fieldGap),

        AppTextField(
          controller: _controller.confirmPassword,
          focusNode: _confirmFocus,
          placeholder: ResetPasswordStrings.confirmPassword,
          errorText: _controller.confirmPasswordError,
          enabled: !busy,
          obscureText: _controller.obscureConfirm,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
          suffix: _buildToggle(
            hidden: _controller.obscureConfirm,
            onTap: _controller.toggleObscureConfirm,
            enabled: !busy,
          ),
        ),
      ],
    );
  }

  /// Same band as login: one line of red, inside space the layout already
  /// leaves, so an error never shifts what is under it.
  Widget _buildMessageBand() {
    final message = _controller.message;

    return SizedBox(
      height: AppDimens.formToButtons,
      child: message == null
          ? null
          : Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  message,
                  style: AppTypography.fieldError,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
    );
  }

  Widget _buildToggle({
    required bool hidden,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Semantics(
      button: true,
      label: hidden
          ? ResetPasswordStrings.showPassword
          : ResetPasswordStrings.hidePassword,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            hidden ? AppIcons.eyeClosed : AppIcons.eye,
            size: 20,
            color: enabled ? AppColors.textSecondary : AppColors.disabled,
          ),
        ),
      ),
    );
  }
}
