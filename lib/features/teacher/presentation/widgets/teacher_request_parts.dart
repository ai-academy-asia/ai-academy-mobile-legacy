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
// Phase 1 (Issue #449) wires listing and sending: "Багш нар" shows a
// [TeacherConfirmationCard] titled "Хүсэлт илгээгдлээ" once the server has
// confirmed a send. Phase 2 (Issue #453) opens [TeacherIncomingRequestSheet]
// from a `schedule_change_request` notification, filled from the request's
// own brief; its actions are nullable callbacks — inert without one, never a
// faked answer.

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
        final fits = [
          first,
          second,
        ].every((pill) => pill.oneLineWidth(context) <= half);
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
}

/// Between the two pills of a [TeacherPillPair].
const double _pairGap = 8;

/// A teacher's placeholder avatar, name and "Teacher" — the "Багш нар" rows'
/// leading part and the incoming-request sheet's sender. The contract's
/// `photo_url` is always null (Issue #449), so the avatar is a neutral
/// placeholder.
///
/// [wrapName] lets a name too long for one line wrap instead of ending in
/// an ellipsis (Issue #557) — for an identity given its row's full width:
/// a stacked "Багш нар" row, and the incoming sheet's sender.
class TeacherIdentity extends StatelessWidget {
  const TeacherIdentity({required this.name, super.key, this.wrapName = false});

  final String name;
  final bool wrapName;

  /// The avatar and its gap: what the name and "Teacher" sit after.
  static const double leadingWidth = _avatarSize + _avatarToName;

  /// [name] laid out on one line, as the identity draws it.
  static double oneLineNameWidth(BuildContext context, String name) =>
      _oneLineWidth(context, name, _nameStyle);

  /// "Teacher" laid out on one line, as the identity draws it.
  static double oneLineRoleWidth(BuildContext context) =>
      _oneLineWidth(context, TeacherScheduleStrings.teacherRole, _roleStyle);

  static double _oneLineWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

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
                style: _nameStyle.copyWith(color: palette.teacherNameInk),
                maxLines: wrapName ? null : 1,
                overflow: wrapName ? null : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                TeacherScheduleStrings.teacherRole,
                style: _roleStyle.copyWith(color: palette.teacherRoleInk),
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

/// The identity's name and "Teacher", measured and drawn alike.
const TextStyle _nameStyle = AppTypography.itemTitle;
const TextStyle _roleStyle = AppTypography.caption;

/// The sheet a teacher would answer an incoming request on (screenshot 6):
/// the requesting teacher, the class and its session — the date and times
/// it would hand over — then "Татгалзах" and "Зөвшөөрөх".
///
/// [onDecline] and [onAccept] are null while an answer cannot be sent —
/// inert, never a faked answer. Phase 2 (Issue #453) fills it through
/// [TeacherIncomingRequestSheet.brief] from the request itself, with a
/// [message] — where the request stands, or why an answer failed — and no
/// pills once it is no longer `pending` ([showActions]).
class TeacherIncomingRequestSheet extends StatelessWidget {
  const TeacherIncomingRequestSheet({
    required this.senderName,
    required TeacherClass this.teacherClass,
    required this.sessionLabel,
    required this.onDecline,
    required this.onAccept,
    super.key,
  }) : courseTitle = null,
       cohortName = null,
       room = null,
       message = null,
       showActions = true;

  /// The same sheet for a request known only by its own brief (Issue
  /// #453): the card shows [courseTitle], [cohortName] and [room] — no
  /// track or student count, which the request does not carry.
  const TeacherIncomingRequestSheet.brief({
    required this.senderName,
    required String this.courseTitle,
    required this.sessionLabel,
    required this.onDecline,
    required this.onAccept,
    super.key,
    this.cohortName,
    this.room,
    this.message,
    this.showActions = true,
  }) : teacherClass = null;

  /// The requesting teacher's name.
  final String senderName;

  /// The class the session belongs to — the default sheet's card. Null for
  /// [TeacherIncomingRequestSheet.brief].
  final TeacherClass? teacherClass;

  /// [TeacherIncomingRequestSheet.brief]'s card parts.
  final String? courseTitle;
  final String? cohortName;
  final String? room;

  /// A line under the card: where the request stands, or why an answer
  /// failed. Null draws none.
  final String? message;

  /// Whether to draw "Татгалзах" / "Зөвшөөрөх" — only while the request is
  /// `pending`.
  final bool showActions;

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
            TeacherIdentity(name: senderName, wrapName: true),
            const SizedBox(height: 20),
            if (teacherClass case final teacherClass?)
              TeacherClassCard(
                teacherClass: teacherClass,
                timeLabel: sessionLabel,
                compactDetails: true,
              )
            else
              TeacherClassCard.brief(
                title: courseTitle!,
                caption: cohortName,
                room: room,
                timeLabel: sessionLabel,
                compactDetails: true,
              ),
            if (message case final message?) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTypography.supporting.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showActions) ...[
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
