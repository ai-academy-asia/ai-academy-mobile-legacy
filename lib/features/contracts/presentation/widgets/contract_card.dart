import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/home_strings.dart';
import '../../../home/presentation/widgets/home_badges.dart';
import '../../domain/student_contract.dart';
import '../contract_strings.dart';

// Measured off the Figma export `e-contract1.png` at its native 3× (Issue
// #312). The card is the same family as Adult Home's `ProgramCard` summary —
// the same wash, badge row, caption and title — so those parts are reused,
// not redrawn.

/// Content sits 16 in from the card's edge; the badge row 24 below its top,
/// the action 24 above its bottom.
const double _paddingH = 16;
const double _paddingV = 24;

/// Badge row to caption, and title to action.
const double _groupGap = 24;

/// The least room between the badge and the pill on a narrow phone.
const double _badgeToPill = 8;

/// The action pill: 44 tall. The export's download glyph inks ~18 wide, 10
/// after "Гэрээ татах", and its caret ~9 × 16, 15 after "Гэрээ байгуулах" —
/// the boxes below are those inks with each glyph's own inset.
const double _actionHeight = AppDimens.buttonHeight;
const double _downloadGlyphSize = 26;
const double _downloadGap = 5;
const double _caretSize = 26;
const double _caretGap = 4;

/// The spinner a busy download shows in place of its label.
const double _spinnerSize = 20;

/// The download glyph the certificate and lesson-material pills use.
const String _downloadGlyph =
    'assets/images/course_learning/exercise_download.svg';

/// One contract on the E-Contract list (Issue #312) — the export's card:
/// the track badge and status pill, the cohort over its course, and the
/// action pill.
///
/// **Only the contract's own fields are drawn:**
///  * the badge from `course.level`, only when it is `adult` or `junior` —
///    [TrackBadge] reads anything else as adult, so another value draws none;
///  * the caption is `cohort.name` and the title the course title (Mongolian
///    first), as Home's program card draws a cohort; with only one of the
///    two it becomes the title alone, and with neither the contract number;
///  * the pill and action from `status`:
///    - `signed` — "Гэрээ байгуулсан" and "Гэрээ татах", enabled only while
///      `document_url` says a signed PDF exists and [onDownload] is given;
///    - `pending` — "Гэрээ хийгдээгүй байна" and "Гэрээ байгуулах", enabled
///      only when `can_sign` and [onSign] is given;
///    - `cancelled` or a status this build does not know — neither pill nor
///      action: no design draws them, and neither may read as signed or
///      pending.
///
/// **Colours.** The pending pill is the export's own `warningFill` and
/// `warningInk`; the signed pill's fill is `infoFill`. The export's signed
/// ink (`#007BE5`) and the two pill edges (`#84CAFF`, `#FFE8A3`) have no
/// exact role, so the nearest ones stand in: `infoInk`, `accentSubtleOutline`
/// and `warningOutline` at 30%.
///
/// A disabled action goes flat as `AppButton`'s outlined variant does — the
/// `disabled` edge, the label and glyph in `disabledInk`, no ripple — and is
/// announced as a disabled button.
class ContractCard extends StatelessWidget {
  const ContractCard({
    super.key,
    required this.contract,
    this.downloading = false,
    this.onDownload,
    this.onSign,
  });

  final StudentContract contract;

  /// A download for this contract is in flight: the pill shows a spinner.
  final bool downloading;

  final VoidCallback? onDownload;
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);
    final level = contract.course?.level;
    final (caption, title) = _captionAndTitle(contract);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        border: Border.all(color: palette.outline),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Home's program-card wash, 1:1 from the top-left.
            Positioned.fill(
              child: SvgPicture.asset(
                HomeIcons.cardBackground,
                fit: BoxFit.none,
                alignment: Alignment.topLeft,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _paddingH - AppDimens.borderWidth,
                _paddingV - AppDimens.borderWidth,
                _paddingH - AppDimens.borderWidth,
                _paddingV - AppDimens.borderWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: homeBadgeHeight,
                    child: Row(
                      // The pill hangs from the top of the badge row.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (level == 'adult' || level == 'junior') ...[
                          TrackBadge(level!),
                          const SizedBox(width: _badgeToPill),
                        ],
                        // Right-aligned as drawn; on a phone narrower than
                        // the export the pill shrinks rather than overflow.
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topRight,
                              child: _statusPill(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _groupGap),
                  if (caption != null)
                    Text(
                      caption,
                      style: _captionStyle.copyWith(
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (title != null)
                    Text(
                      title,
                      style: _titleStyle.copyWith(color: palette.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ?_action(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(BuildContext context) {
    final palette = context.palette;
    return switch (contract.status) {
      StudentContractStatus.signed => HomeCapsule(
        label: ContractStrings.statusSigned,
        outline: palette.accentSubtleOutline,
        fill: palette.infoFill,
        ink: palette.infoInk,
        horizontalPadding: 15,
      ),
      StudentContractStatus.pending => HomeCapsule(
        label: ContractStrings.statusPending,
        outline: palette.warningOutline.withValues(alpha: 0.3),
        fill: palette.warningFill,
        ink: palette.warningInk,
        horizontalPadding: 15,
      ),
      StudentContractStatus.cancelled ||
      StudentContractStatus.unknown => const SizedBox.shrink(),
    };
  }

  Widget? _action() {
    final pill = switch (contract.status) {
      StudentContractStatus.signed => _ActionPill(
        label: ContractStrings.download,
        trailing: _ActionTrailing.download,
        busy: downloading,
        onPressed: contract.documentUrl != null ? onDownload : null,
      ),
      StudentContractStatus.pending => _ActionPill(
        label: ContractStrings.sign,
        trailing: _ActionTrailing.caret,
        onPressed: contract.canSign ? onSign : null,
      ),
      StudentContractStatus.cancelled || StudentContractStatus.unknown => null,
    };
    if (pill == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: _groupGap),
      child: pill,
    );
  }
}

/// The caption and title the card draws — see [ContractCard].
(String?, String?) _captionAndTitle(StudentContract contract) {
  final course = contract.course;
  final courseTitle = course?.titleMn ?? course?.titleEn;
  final cohortName = contract.cohort?.name;
  if (courseTitle != null && cohortName != null) {
    return (cohortName, courseTitle);
  }
  return (null, courseTitle ?? cohortName ?? contract.contractNumber);
}

enum _ActionTrailing { download, caret }

/// The export's white action pill: the outline edge, the label centred with
/// its glyph after it.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.trailing,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final _ActionTrailing trailing;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final available = onPressed != null;
    final ink = available ? palette.textPrimary : palette.disabledInk;

    return Semantics(
      container: true,
      button: true,
      enabled: available && !busy,
      label: label,
      // The tap is announced here: excluding the children's semantics also
      // drops the InkWell's own tap action.
      onTap: available && !busy ? onPressed : null,
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: available ? palette.outline : palette.disabled,
          ),
        ),
        child: InkWell(
          onTap: busy ? null : onPressed,
          customBorder: const StadiumBorder(),
          // 44 tall as drawn, growing only when large accessibility text
          // needs more, rather than clipping the label.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _actionHeight),
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: _spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ellipsised rather than overflowing when large text
                        // meets a narrow phone (e.g. 2.0× at 320pt).
                        Flexible(
                          child: Text(
                            label,
                            style: _actionStyle.copyWith(color: ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...switch (trailing) {
                          _ActionTrailing.download => [
                            const SizedBox(width: _downloadGap),
                            SvgPicture.asset(
                              _downloadGlyph,
                              width: _downloadGlyphSize,
                              height: _downloadGlyphSize,
                              // Always tinted with the label's ink: the SVG's
                              // strokes are hard-coded black, which vanishes
                              // on the dark theme's button (review of #313).
                              colorFilter: ColorFilter.mode(
                                ink,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                          _ActionTrailing.caret => [
                            const SizedBox(width: _caretGap),
                            Icon(
                              AppIcons.caretRight,
                              size: _caretSize,
                              color: ink,
                            ),
                          ],
                        },
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ProgramCard`'s caption and title: 12 over 18/700.
final TextStyle _captionStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 12,
  height: 18 / 12,
);

final TextStyle _titleStyle = AppTypography.cardHeading.copyWith(
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
);

const TextStyle _actionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);
