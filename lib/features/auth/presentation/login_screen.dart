import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/http_auth_repository.dart';
import '../domain/auth_repository.dart';
import 'login_controller.dart';
import 'login_strings.dart';
import 'widgets/contact_manager_card.dart';
import 'widgets/remember_me_checkbox.dart';

/// Sign in.
///
/// Reproduces the Adult login flow — Figma `Sign in - 1` … `5` (node
/// `31019:13426` and siblings, section "Login", page "📱 - App UI"). The
/// vertical rhythm is the design's own, read from the frame geometry and kept
/// in [AppDimens]: 88 to the heading, 24 to the form, 12 between fields, 40 to
/// the buttons, 12 between them, and an 80pt card at the bottom.
///
/// There is no logo on this screen — the design leaves the 88pt band above the
/// heading empty.
///
/// The design frame is a fixed 393 x 852 artboard. Here the content stretches
/// to the device width behind fixed 16pt gutters, and the band between the form
/// and the bottom card flexes, so the card sits at the bottom of a taller phone
/// and the screen scrolls on a shorter one.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repository, this.onSignedIn, this.onResetPassword});

  /// Defaults to the real API. Injected in tests.
  final AuthRepository? repository;

  /// Where to go after a successful sign-in. Defaults to `/home`.
  final VoidCallback? onSignedIn;

  /// What the "Нууц үг сэргээх" button does. Defaults to `/reset-password`.
  final VoidCallback? onResetPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = LoginController(repository: widget.repository ?? HttpAuthRepository());
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final session = await _controller.submit();
    if (session == null || !mounted) return;

    if (widget.onSignedIn != null) {
      widget.onSignedIn!();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _openResetPassword() {
    FocusScope.of(context).unfocus();
    if (widget.onResetPassword != null) {
      widget.onResetPassword!();
    } else {
      Navigator.of(context).pushNamed('/reset-password');
    }
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
        // The keyboard overlays the screen instead of shrinking it. In the
        // reference the form does not move when the keypad appears — it simply
        // covers the bottom card — and resizing would jerk that card up to meet
        // it. The scroll padding below keeps everything reachable regardless.
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          // Tapping the background dismisses the keyboard.
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  // Grows the scrollable extent by the height of the keyboard so
                  // a short screen can still scroll a covered field into view,
                  // without the layout itself resizing.
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
                                const SizedBox(height: AppDimens.headingTop),

                                Text(LoginStrings.heading, style: AppTypography.heading),
                                const SizedBox(height: AppDimens.headingToForm),

                                _buildForm(),

                                // Flexes so the card sits at the bottom of a
                                // tall screen and collapses on a short one.
                                const Spacer(),
                                const SizedBox(height: 24),

                                ContactManagerCard(
                                  supportingText: LoginStrings.contactSupporting,
                                  title: LoginStrings.contactManager,
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

  Widget _buildForm() {
    final busy = _controller.submitting;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller.identifier,
            placeholder: LoginStrings.identifierPlaceholder,
            floatingLabel: LoginStrings.identifierLabel,
            errorText: _controller.identifierError,
            enabled: !busy,
            // The field takes an address as well as a number, so it cannot use
            // the numeric pad the reference shows: that pad has no letters and
            // would lock out the "Email хаяг" half of the field.
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: AppDimens.fieldGap),

          AppTextField(
            controller: _controller.password,
            focusNode: _passwordFocus,
            placeholder: LoginStrings.passwordLabel,
            errorText: _controller.passwordError,
            enabled: !busy,
            obscureText: _controller.obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            suffix: _buildPasswordToggle(enabled: !busy),
          ),
          const SizedBox(height: AppDimens.fieldsToCheckbox),

          RememberMeCheckbox(
            value: _controller.rememberMe,
            label: LoginStrings.rememberMe,
            onChanged: busy ? null : (value) => _controller.setRememberMe(value: value),
          ),

          _buildMessageBand(),

          AppButton(
            // Live even with the fields empty — the reference draws it in full
            // brand blue in the resting state. Pressing an empty form is what
            // surfaces the field errors, which is the point of Sign in - 4/5.
            label: LoginStrings.signIn,
            loading: busy,
            onPressed: busy ? null : _submit,
          ),
          const SizedBox(height: AppDimens.buttonGap),

          AppButton(
            label: LoginStrings.resetPassword,
            variant: AppButtonVariant.outlined,
            onPressed: busy ? null : _openResetPassword,
          ),
        ],
      ),
    );
  }

  /// The 40pt gap the design leaves between the checkbox and the buttons,
  /// doubling as the slot for the one line of red text.
  ///
  /// Putting the message *inside* the existing gap rather than adding a row of
  /// its own is what keeps the error states aligned with the reference: the
  /// buttons do not shift and no banner appears. The field's own red border and
  /// red label say which input is at fault; this says why.
  Widget _buildMessageBand() {
    final message = _controller.message;

    return SizedBox(
      height: AppDimens.formToButtons,
      child: message == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: AppTypography.fieldError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }

  Widget _buildPasswordToggle({required bool enabled}) {
    final hidden = _controller.obscurePassword;
    return Semantics(
      button: true,
      label: hidden ? LoginStrings.showPassword : LoginStrings.hidePassword,
      child: InkWell(
        onTap: enabled ? _controller.toggleObscurePassword : null,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            // Hidden shows the closed eye, matching the reference.
            hidden ? AppIcons.eyeClosed : AppIcons.eye,
            size: 20,
            color: enabled ? AppColors.textSecondary : AppColors.disabled,
          ),
        ),
      ),
    );
  }
}
