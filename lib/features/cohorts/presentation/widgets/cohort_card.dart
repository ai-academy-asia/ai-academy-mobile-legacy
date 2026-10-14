import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/track_badge.dart';
import '../../../enrollments/presentation/enrollment_strings.dart';
import '../../domain/cohort.dart';
import '../cohort_list_strings.dart';

/// The card's shortest height, border included: Figma's "148 Hug" for a card
/// with no progress. A minimum, not a fixed height — a card with progress or
/// an enroll button is already taller than this and keeps its own size.
const double _minHeight = 148;

/// How strongly the status pill's own colour tints its fill, for a status the
/// reference does not draw and whose fill therefore has no measured value.
const double _pillTintOpacity = 0.12;

/// The progress bar, measured off the reference: 8 tall (not the global
/// [AppDimens.progressBarHeight] of 6, which other screens rely on), filled in
/// the reference's blue and tracked in the same grey as the card's outline.
const double _progressBarHeight = 8;

/// The badge row to the caption: 24 in Figma.
const double _rowToCaptionGap = 24;

/// The cohort's name over the course's, as on every card that names a course.
const TextStyle _captionStyle = AppTypography.caption;

/// The course's name — the same style on every card and page that shows one.
const TextStyle _titleStyle = AppTypography.cardTitle;

/// One cohort in the list — matches the Figma "Course Catalog" (cohorts)
/// frame's card: an Adult badge and a status pill on top, the cohort's
/// caption and title, then the enroll action. One of the program/cohort card
/// family (Issue #404): the shared [CardBadgeRow], [TrackBadge] and
/// [CardCapsule], the family's [programCardPadding], and the
/// [CohortCardPattern] on [AppPalette.surfaceTinted], edged in
/// [AppPalette.outline] at [AppDimens.borderWidth], with every content
/// card's [AppDimens.homeCardRadius] (Issue #368).
///
/// The schedule/classroom/teacher/seats fields `Cohort` carries are no longer
/// shown here — the reference has no place for them. They still exist on the
/// model; nothing about `Cohort`, its repository, or the enrollment flow
/// changed, only what this one card chooses to render.
///
/// The enroll action sits under the summary as the same full-width [AppButton]
/// every other screen's primary action uses. The card only draws the action's
/// state — in flight, failed — which `EnrollmentController` owns and the list
/// screen hands in. Once enrolled the button simply goes; the card draws no
/// "enrolled" row in its place, so an enrolled cohort's card is the compact
/// summary alone.
class CohortCard extends StatelessWidget {
  const CohortCard({
    required this.cohort,
    super.key,
    this.onEnroll,
    this.enrolling = false,
    this.enrolled = false,
    this.enrollError,
    this.progressPct,
    this.onTap,
  });

  final Cohort cohort;

  /// Opens the cohort's course in `CourseModuleListScreen`. Null leaves the
  /// card inert, same as [onEnroll].
  final VoidCallback? onTap;

  /// How far through the course the student is, as `GET /me/cohorts` reports
  /// it. Null draws no progress row at all — a missing figure is not 0%, and
  /// every card without one looks exactly as it did before this existed.
  final double? progressPct;

  /// What the enroll button does. Null leaves the button off, so the card
  /// reads as a plain summary.
  final VoidCallback? onEnroll;

  /// An enroll request for this cohort is in flight.
  final bool enrolling;

  /// The API has created an enrollment for this cohort. Removes the button.
  final bool enrolled;

  /// Why the last enroll attempt failed. Shown in red under the button, the
  /// way the login screen shows a field's error under the field.
  final String? enrollError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surfaceTinted,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: _minHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            border: Border.all(
              color: context.palette.outline,
              width: AppDimens.borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            child: Stack(
              children: [
                // The reference's decorative shapes, behind the content —
                // shared with Teacher Programs' card (Issue #404).
                const CohortCardPattern(),
                Padding(
                  padding: programCardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The family's shared row: the badge left and the status
                      // right, the status under the badge only where enlarged
                      // text leaves no room (Issues #366, #404). `Cohort`
                      // carries no level, so the badge is the one the
                      // reference shows on every card: Adult.
                      CardBadgeRow(
                        track: 'adult',
                        trailing: _StatusPill(cohort.status),
                      ),
                      const SizedBox(height: _rowToCaptionGap),

                      if (_preferMongolian(
                            cohort.course.title.mn,
                            cohort.course.title.en,
                          )
                          case final courseTitle?) ...[
                        // A small caption above the bold heading: [cohort.name] is
                        // the specific instance (e.g. "Corporate Leaders 2026-08"),
                        // [courseTitle] the programme it belongs to — matching the
                        // reference's "Cohort 0N" caption over the bold title.
                        Text(
                          cohort.name,
                          style: _captionStyle.copyWith(
                            color: context.palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // The caption's and title's line boxes sit flush in Figma.
                        Text(
                          courseTitle,
                          style: _titleStyle.copyWith(
                            color: context.palette.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else
                        // No course title to caption: falls back to the single
                        // heading this card always showed, rather than leaving the
                        // card with no bold line at all.
                        Text(
                          cohort.name,
                          style: _titleStyle.copyWith(
                            color: context.palette.textPrimary,
                          ),
                          maxLines: 2,
                        ),

                      if (progressPct case final progressPct?) ...[
                        const SizedBox(height: 12),
                        _Progress(
                          percent: progressPct.round().clamp(0, 100).toInt(),
                        ),
                      ],

                      if (!enrolled && onEnroll != null) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          label: EnrollmentStrings.enroll,
                          loading: enrolling,
                          onPressed: onEnroll,
                        ),
                      ],

                      if (enrollError case final message?) ...[
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: AppTypography.fieldHelper.copyWith(
                            color: context.palette.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The percentage and its bar — the same treatment Home's program card gives
/// the same figure: the value right-aligned above a rounded determinate bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            CohortListStrings.percentComplete(percent),
            style: AppTypography.supporting.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: _progressBarHeight,
            backgroundColor: context.palette.outline,
            valueColor: AlwaysStoppedAnimation<Color>(context.palette.accent),
          ),
        ),
      ],
    );
  }
}

/// Mongolian first — every other string in the app is — falling back to
/// English, and to null only when the API sent neither. Matches
/// `course_card.dart`'s helper; not shared, since neither file currently
/// depends on the other.
String? _preferMongolian(String? mn, String? en) {
  if (mn != null && mn.isNotEmpty) return mn;
  if (en != null && en.isNotEmpty) return en;
  return null;
}

/// `"open"` -> `"Open"`. Values are shown verbatim otherwise — `status` has
/// no confirmed closed set, so this only tidies capitalisation, it never
/// maps or translates.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// The cohort's status, as a tinted capsule in the top-right corner.
///
/// Colours are the reference's own, which are not the obvious semantic
/// mapping: **finished is blue and both active and open are green**, rather
/// than green-for-done. Taken from the frame as drawn rather than corrected,
/// the same way every other value on this screen is — including the fills,
/// which are flat sampled colours and not the outline colour at an alpha.
///
/// Only "open" is a confirmed value of [Cohort.status]; "active" and
/// "finished" are the reference's other two pills, matched on the same
/// unconfirmed-value basis "open" already was. Any other value falls back to a
/// neutral outline rather than a guessed colour.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    // Outline, label and fill by role. The reference draws each pill's label
    // in its outline's colour; they stay separate roles because one is a line
    // and one is text — the same light value, not the same meaning.
    final palette = context.palette;
    final (Color outline, Color label, Color fill) = switch (status
        .toLowerCase()) {
      'open' => (
        palette.successOutline,
        palette.successLabel,
        palette.successFill,
      ),
      'active' => (
        palette.successOutline,
        palette.successLabel,
        palette.successFill,
      ),
      'finished' => (palette.infoInk, palette.infoInk, palette.infoFill),
      // Not a status the reference draws, so there is no fill to sample: the
      // neutral outline gets the app's standard low-alpha wash of itself.
      _ => (
        palette.textSecondary,
        palette.textSecondary,
        palette.textSecondary.withValues(alpha: _pillTintOpacity),
      ),
    };

    // The shared capsule, in this card's own documented colours (Issue
    // #404): the label sits in its outline's green, `successLabel`.
    return CardCapsule(
      label: _capitalize(status),
      outline: outline,
      fill: fill,
      ink: label,
      horizontalPadding: 15,
    );
  }
}
