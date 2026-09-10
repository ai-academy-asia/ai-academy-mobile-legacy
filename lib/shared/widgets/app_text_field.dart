import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// The design's input field: a 56pt outlined box whose label starts inside the
/// field and rises into a notch in the top border once the field is focused or
/// filled.
///
/// That notched-label behaviour is exactly what Material's outlined
/// `InputDecoration` does, so this leans on it rather than redrawing it — a
/// hand-rolled notch would be a lot of paint code for the same result. What is
/// customised is everything Material would otherwise impose: the shape, the
/// stroke weights, the colours and the type.
///
/// [placeholder] and [floatingLabel] are separate because the design shortens
/// the text as it rises: the first field rests as "Утасны дугаар / Email хаяг"
/// and floats as "Утасны дугаар". Swapping [InputDecoration.labelText] at the
/// moment the label leaves the field reproduces that.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    required this.placeholder,
    super.key,
    String? floatingLabel,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
    this.focusNode,
  }) : floatingLabel = floatingLabel ?? placeholder;

  final TextEditingController controller;

  /// Sits inside the field while it is empty and unfocused.
  final String placeholder;

  /// Sits in the border notch once the field is focused or filled. Defaults to
  /// [placeholder] for fields whose label does not change.
  final String floatingLabel;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;

  /// Non-null puts the field in its error state: red border and red label.
  final String? errorText;

  /// Trailing control inside the box — the password visibility toggle.
  final Widget? suffix;

  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownedNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
    // The label position depends on whether the field has content, so the
    // field has to rebuild as the text changes, not only as focus moves.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _node.addListener(_onFocusChanged);
      _onFocusChanged();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final focused = _node.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _ownedNode?.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final floating = _focused || widget.controller.text.isNotEmpty;

    // Error outranks focus: a red box that turns blue when tapped would hide
    // the very thing the user has to fix.
    final Color labelColor = hasError
        ? AppColors.error
        : (_focused ? AppColors.borderFocused : AppColors.textSecondary);

    return TextField(
      controller: widget.controller,
      focusNode: _node,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      style: AppTypography.fieldValue,
      cursorColor: AppColors.borderFocused,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        // The resting text is the long placeholder; the floating text is the
        // short label. Both ride the same slot, so the swap happens exactly as
        // the label lifts.
        labelText: floating ? widget.floatingLabel : widget.placeholder,
        labelStyle: AppTypography.fieldPlaceholder,
        floatingLabelStyle: AppTypography.fieldFloatingLabel.copyWith(color: labelColor),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        // The reference shows no message under an errored field — the red
        // border and red label carry the state. The text is still supplied so
        // the reason is not lost; see LoginScreen for where it surfaces.
        errorText: null,
        filled: true,
        fillColor: widget.enabled ? AppColors.surface : AppColors.surfaceMuted,
        isDense: false,
        // 18 + 20 (one line of 15/20 type) + 18 lands the box on the design's
        // 56pt. Material draws the outline inside this, not around it.
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: _border(
          hasError ? AppColors.error : AppColors.border,
          hasError ? AppDimens.borderWidthEmphasis : AppDimens.borderWidth,
        ),
        focusedBorder: _border(
          hasError ? AppColors.error : AppColors.borderFocused,
          AppDimens.borderWidthEmphasis,
        ),
        disabledBorder: _border(AppColors.border, AppDimens.borderWidth),
        border: _border(AppColors.border, AppDimens.borderWidth),
        suffixIcon: widget.suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
