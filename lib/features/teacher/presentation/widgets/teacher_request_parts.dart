import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/teacher_class.dart';
import '../teacher_schedule_strings.dart';
import 'teacher_class_card.dart';
import 'teacher_pill_button.dart';

// The schedule-change request's UI (Issue #372), measured off the Teacher
// redesign's 3x exports.
//
// **UI only — blocked by a BACKEND GAP.** No verified endpoint lists the
// teachers a session can be handed to, creates, lists, accepts or rejects a
// request, or notifies another teacher (`DATA_AND_API.md`). So nothing in the
// app opens [TeacherRequestSentCard] or [TeacherIncomingRequestSheet]: they
// are built and tested, ready for real request data, and every action is a
// nullable callback — inert without one, never a faked success.

/// Two pills side by side under a sheet's card — "Цаг солих" / "Ирц
/// бүртгэх", "Татгалзах" / "Зөвшөөрөх": 44 tall, sharing the width with 8
/// between them, as the references draw both pairs.
///
/// Where enlarged text leaves a label wider than its half, the pair stacks,
/// each pill full width, rather than cutting a label short.
class TeacherPillPair extends StatelessWidget {
  const TeacherPillPair({required this.first, required this.second, super.key});

  final TeacherPillButton first;
  final TeacherPillButton second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - _pairGap) / 2;
        final fits = [first, second].every(
          (pill) =>
              _labelWidth(context, pill) + 2 * pill.horizontalPadding <= half,
        );
        if (fits) {
          return Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: _pairGap),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            const SizedBox(height: _pairGap),
            second,
          ],
        );
      },
    );
  }

  /// [pill]'s label laid out on one line, as the pill draws it.
  static double _labelWidth(BuildContext context, TeacherPillButton pill) {
    final painter = TextPainter(
      text: TextSpan(
        text: pill.label,
        style: DefaultTextStyle.of(context).style.merge(
          AppTypography.buttonLabel.copyWith(
            fontSize: pill.fontSize,
            height: 1.2,
          ),
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// Between the two pills of a [TeacherPillPair].
const double _pairGap = 8;

/// A teacher's placeholder avatar, name and "Teacher" — the "Багш нар" rows'
/// leading part and the incoming-request sheet's sender. No photo field is
/// known (BACKEND GAP), so the avatar is a neutral placeholder.
class TeacherIdentity extends StatelessWidget {
  const TeacherIdentity({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          // A placeholder avatar on the icon-tile ground (`surfaceSubtle`),
          // its person glyph `avatarPlaceholderInk`.
          decoration: BoxDecoration(
            color: palette.surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(
            AppIcons.user,
            size: 28,
            color: palette.avatarPlaceholderInk,
          ),
        ),
        const SizedBox(width: _avatarToName),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.itemTitle.copyWith(
                  color: palette.teacherNameInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                TeacherScheduleStrings.teacherRole,
                style: AppTypography.caption.copyWith(
                  color: palette.teacherRoleInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The avatar, and its gap to the name: the name's left edge on 97.
const double _avatarSize = 64;
const double _avatarToName = 17;

/// The acknowledgement once a schedule-change request is **confirmed sent**
/// by the server (screenshot 4: "Хүсэлт илгээгдлээ" / "Ойлголоо"): the
/// success disc, the title, and the full-width "Ойлголоо" that dismisses it.
///
/// A post-send success state — so it must only be shown for a request the
/// server has accepted. Nothing in the app shows it yet (see the file's
/// notes).
class TeacherRequestSentCard extends StatelessWidget {
  const TeacherRequestSentCard({required this.onDismiss, super.key});

  /// "Ойлголоо". Null leaves it inert.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      // The reference's 16 / 29 / 16 to the card's outer edge, its 1pt
      // outline included.
      padding: const EdgeInsets.fromLTRB(15, 28, 15, 15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: palette.outlineFaint),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: _successDisc,
              height: _successDisc,
              decoration: BoxDecoration(
                color: palette.successFillStrong,
                shape: BoxShape.circle,
                border: Border.all(color: palette.successInk, width: 2.5),
              ),
              child: Icon(AppIcons.check, size: 18, color: palette.successInk),
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              TeacherScheduleStrings.requestSentTitle,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TeacherPillButton(
            label: TeacherScheduleStrings.requestSentDismiss,
            wrapLabel: true,
            variant: TeacherPillVariant.filled,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The success disc: 37 across with its ring, as the reference draws it.
const double _successDisc = 37;

/// The sheet a teacher would answer an incoming request on (screenshot 6):
/// the requesting teacher, the class and its session — the date and times
/// it would hand over — then "Татгалзах" and "Зөвшөөрөх".
///
/// UI only: no notification kind or request data exists to open it from, and
/// no endpoint accepts or rejects a request. [onDecline] and [onAccept] are
/// null until one does — inert, never a faked answer.
class TeacherIncomingRequestSheet extends StatelessWidget {
  const TeacherIncomingRequestSheet({
    required this.senderName,
    required this.teacherClass,
    required this.sessionLabel,
    required this.onDecline,
    required this.onAccept,
    super.key,
  });

  /// The requesting teacher's name.
  final String senderName;

  /// The class the session belongs to.
  final TeacherClass teacherClass;

  /// The session's date and times, e.g. "11-р сарын 17 • 14:00-17:00".
  final String sessionLabel;

  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          8,
          AppDimens.screenPadding,
          AppDimens.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeacherSheetHandle(),
            const SizedBox(height: 20),
            TeacherIdentity(name: senderName),
            const SizedBox(height: 20),
            TeacherClassCard(
              teacherClass: teacherClass,
              timeLabel: sessionLabel,
            ),
            const SizedBox(height: 24),
            TeacherPillPair(
              first: TeacherPillButton(
                label: TeacherScheduleStrings.requestDecline,
                wrapLabel: true,
                variant: TeacherPillVariant.danger,
                onPressed: onDecline,
              ),
              second: TeacherPillButton(
                label: TeacherScheduleStrings.requestAccept,
                wrapLabel: true,
                variant: TeacherPillVariant.filled,
                onPressed: onAccept,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The drag handle at the top of the Teacher sheets: 72 x 6, `sheetHandle`.
class TeacherSheetHandle extends StatelessWidget {
  const TeacherSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 6,
        decoration: BoxDecoration(
          color: context.palette.sheetHandle,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
