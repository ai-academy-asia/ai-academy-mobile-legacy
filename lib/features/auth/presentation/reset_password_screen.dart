import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../data/http_password_repository.dart';
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
///
/// **Two flows, one screen** (Issue #227). The required change for a
/// `must_change_password` account (`openSignedIn`, Issue #182) replaces the
/// route and draws no back control — the frames draw none, and there is
/// nothing it may return to. A voluntary change — Profile's "Change
/// password", or Login's "Нууц үг сэргээх" with a session held — is pushed
/// over another screen and opts in with [showBackButton].
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.repository,
    this.onCompleted,
    this.showBackButton = false,
  });

  /// Defaults to the real API. Injected in tests.
  final PasswordRepository? repository;

  /// Called once the password has been changed. Defaults to popping back.
  final VoidCallback? onCompleted;

  /// Whether to draw the app's back control above the form, popping back to
  /// the screen this was opened from. Off by default, so the required change
  /// stays locked unless a caller explicitly opts in; only the voluntary
  /// change does. The form below it is the same either way.
  final bool showBackButton;

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
      repository: widget.repository ?? HttpPasswordRepository(),
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
      value: AppSystemUi.page(
        context,
        navigationBar: context.palette.surfaceSubtle,
      ),
      child: Scaffold(
        // The reference's own page fill (#F9FAFB), which `surfaceSubtle` holds
        // exactly — same correction the login screen carries.
        backgroundColor: context.palette.surfaceSubtle,
        // Same as login: the keyboard overlays rather than resizing, and the
        // scroll padding below keeps every field reachable regardless.
        resizeToAvoidBottomInset: false,
        // The voluntary change's back control, as a row above the unchanged
        // form; the required change has none (see [showBackButton]). 52 is
        // the control's own height: 12 over its 40 circle.
        appBar: widget.showBackButton
            ? const PreferredSize(
                preferredSize: Size.fromHeight(52),
                child: SafeArea(
                  bottom: false,
                  child: CourseLearningBackButton(),
                ),
              )
            : null,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(
                                  height: AppDimens.resetHeadingTop,
                                ),

                                Text(
                                  ResetPasswordStrings.title,
                                  style: AppTypography.heading.copyWith(
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(
                                  height: AppDimens.titleToSupporting,
                                ),
                                Text(
                                  ResetPasswordStrings.supporting,
                                  style: AppTypography.cardSupporting.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppDimens.headingToForm),

                                _buildFields(),

                                // The reference puts the message directly under
                                // the confirm field, above the requirements —
                                // see `Sign in - 10`.
                                _buildMessageBand(),
                                const SizedBox(height: AppDimens.headingToForm),

                                PasswordRequirementsPanel(
                                  satisfied: _controller.satisfiedRequirements,
                                  strength: _controller.strength,
                                  evaluated: _controller.requirementsEvaluated,
                                ),

                                // The reference crop shows nothing below the
                                // requirements, so the button takes the empty
                                // space at the bottom rather than crowding them.
                                const Spacer(),

                                AppButton(
                                  label: ResetPasswordStrings.submit,
                                  loading: _controller.submitting,
                                  onPressed: _controller.submitting
                                      ? null
                                      : _submit,
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

  /// The reference sets the current-password field apart from the pair below
  /// it: measured at 24pt here against [AppDimens.fieldGap]'s 12 between the
  /// new password and its confirmation. Local rather than a token — login's
  /// two fields sit at 12, so this is this screen's grouping, not a new
  /// app-wide rhythm.
  static const double _currentToNewGap = 24;

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
        const SizedBox(height: _currentToNewGap),

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

  /// One line of red directly under the confirm field, as `Sign in - 10`
  /// draws it.
  ///
  /// Unlike login's equivalent, this takes no space of its own when there is
  /// nothing to say: the reference shows the requirements panel sitting ~18pt
  /// lower in the error state than in the resting one, so the message genuinely
  /// pushes what is *below* it down. The three fields sit above it and never
  /// move, which is the position the reference holds fixed.
  Widget _buildMessageBand() {
    final message = _controller.message;
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: AppTypography.fieldError.copyWith(
            color: context.palette.error,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
            color: enabled
                ? context.palette.textSecondary
                : context.palette.disabled,
          ),
        ),
      ),
    );
  }
}
