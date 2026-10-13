import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/teacher_session.dart';

/// "14 / 24", its caption and the bar — [AttendanceCounts.attended] of
/// [AttendanceCounts.total], exactly as the server counted them. The held
/// session sheet's footer (Issue #231) and the QR attendance screen's live
/// tally (Issue #374), which differ only in [caption]'s tense.
class AttendanceTally extends StatelessWidget {
  const AttendanceTally({
    required this.counts,
    required this.caption,
    super.key,
  });

  final AttendanceCounts counts;

  /// Under the count: "оюутан ирцэд бүртгэгдсэн" / "…бүртгэгдлээ".
  final String caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '${counts.attended} / ${counts.total}',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${counts.attended}',
                style: _countStyle.copyWith(color: palette.accentText),
              ),
              Text(
                ' / ${counts.total}',
                style: _totalStyle.copyWith(color: palette.teacherDetailInk),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: _captionStyle.copyWith(color: palette.teacherCaptionInk),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // A plain bar: Material 3's indicator adds a stop dot and a gap the
        // reference does not draw.
        ClipRRect(
          key: const ValueKey('attendance-bar'),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            // `outlineSubtle`'s documented "Teacher's bar track".
            color: palette.outlineSubtle,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: counts.fraction.clamp(0, 1),
              heightFactor: 1,
              child: ColoredBox(
                key: const ValueKey('attendance-fill'),
                color: palette.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The attended count — sized to the tally's hero, a container-sized
/// exception to the type scale (`DESIGN_SYSTEM.md` §3).
final TextStyle _countStyle = AppTypography.display.copyWith(
  fontSize: 36,
  height: 44 / 36,
  fontWeight: FontWeight.w800,
);

/// "/ total" beside the count.
final TextStyle _totalStyle = AppTypography.bodyStrong.copyWith(height: 1.2);

/// "оюутан ирцэд бүртгэгдсэн".
const TextStyle _captionStyle = AppTypography.body;
