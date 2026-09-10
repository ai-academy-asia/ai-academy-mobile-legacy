import 'package:flutter/widgets.dart';

/// Palette for the AI Academy Asia app.
///
/// The brand colours are exact — sampled from the logo exported from Figma
/// (`assets/images/ai_academy_logo.png`). The neutrals are the reference's:
/// a light grey page carrying white controls, with text in plain black at two
/// opacities rather than in the brand navy. Tinting body copy with the navy is
/// what made the first passes read heavy and purple next to the design.
abstract final class AppColors {
  // --- Brand, sampled from the Figma logo export ---------------------------

  /// Interaction and primary action: the filled button, a focused border, the
  /// cursor. The lighter of the logo's two blues.
  static const Color blue = Color(0xFF296CFF);

  /// The deeper blue of the logo mark. Not used for interaction.
  static const Color blueDeep = Color(0xFF0262F8);

  /// Violet terminal of the logo gradient.
  static const Color violet = Color(0xFF4316FF);

  /// Wordmark navy. Belongs to the logo, not to body text.
  static const Color navy = Color(0xFF14053D);

  // --- Neutrals ------------------------------------------------------------

  /// The page. A light grey, which is what makes the white controls read as
  /// surfaces at all.
  static const Color background = Color(0xFFF4F5F7);

  /// Fields, buttons and the bottom card sit on this.
  static const Color surface = Color(0xFFFFFFFF);

  /// Fill of a field that is not accepting input.
  static const Color surfaceMuted = Color(0xFFEFF0F3);

  /// Resting border of a field, the secondary button and the bottom card.
  static const Color border = Color(0xFFE4E6EF);

  /// Border, label and cursor of the field currently being typed into.
  ///
  /// Dark, not blue. Blue is the primary action's colour and nothing else —
  /// a blue focus ring is a Material habit, and the design does not use it.
  static const Color borderFocused = Color(0xE6000000);

  /// Headings, field values, the card title — rgba(0, 0, 0, 0.9).
  static const Color textPrimary = Color(0xE6000000);

  /// Placeholders, resting labels, the card's supporting line and the chevron —
  /// rgba(0, 0, 0, 0.5).
  static const Color textSecondary = Color(0x80000000);

  /// Error border, error label and the validation message. Also a password
  /// requirement the current password fails.
  static const Color error = Color(0xFFE5484D);

  /// A satisfied password requirement, and a full-strength meter.
  ///
  /// Read off the reset-password reference — the design has no green anywhere
  /// on the login screen, so this is the first place it appears.
  static const Color success = Color(0xFF22A06B);

  /// A partly-satisfied strength meter, between [error] and [success].
  static const Color warning = Color(0xFFF0A22E);

  /// Fill of a control that cannot be pressed.
  static const Color disabled = Color(0xFFC9CBDA);

  /// Foreground on filled buttons.
  static const Color onPrimary = Color(0xFFFFFFFF);
}
