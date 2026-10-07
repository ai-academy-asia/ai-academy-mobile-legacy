import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/open_external_url.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/home_strings.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'teacher_gradebook_strings.dart';
import 'teacher_home_strings.dart';
import 'widgets/gradebook_widgets.dart';
import 'widgets/teacher_pill_button.dart';

/// A student's submission (Issue #233), built against the `feedback`
/// reference: a card with the Assignment / Note tabs, and Mentor Feedback
/// at the foot of the screen.
///
/// The submission is the real `GET /teacher/submissions/{id}`. The
/// Assignment tab draws its `link` (opened outside the app, as course
/// materials are) and its `description` in the reference's outlined
/// "Тайлбар" box, then its status and, once reviewed, the score and the
/// feedback message in the same box. Its `file` is not drawn: the download
/// (`/file`) is not verified (BACKEND GAP). The Note tab has no teacher
/// endpoint (BACKEND GAP).
///
/// **Mentor Feedback is inert.** `POST /teacher/submissions/{id}/review`'s
/// request (`{score, feedback}`) is confirmed, but its success and error
/// responses are not (a live call answered 404), so nothing is sent.
class GradebookSubmissionScreen extends StatefulWidget {
  const GradebookSubmissionScreen({
    required this.courseTitle,
    required this.submissionId,
    required this.repository,
    super.key,
    this.openUrl,
  });

  final String courseTitle;
  final int submissionId;
  final TeacherGradebookRepository repository;

  /// Opens the submitted link — `openExternalUrl` unless a test injects one,
  /// as tests must not reach the platform.
  final Future<bool> Function(Uri url)? openUrl;

  @override
  State<GradebookSubmissionScreen> createState() =>
      _GradebookSubmissionScreenState();
}

class _GradebookSubmissionScreenState extends State<GradebookSubmissionScreen> {
  TeacherSubmission? _submission;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _submission = null;
      _error = null;
    });
    try {
      final submission = await widget.repository.getSubmission(
        widget.submissionId,
      );
      if (mounted) setState(() => _submission = submission);
    } on TeacherFailure catch (failure) {
      if (mounted) {
        setState(() => _error = TeacherHomeStrings.messageFor(failure.kind));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = TeacherHomeStrings.messageFor(
            TeacherFailureKind.unexpected,
          ),
        );
      }
    }
  }

  Future<void> _openLink(String link) async {
    final url = Uri.tryParse(link);
    final opened =
        url != null && await (widget.openUrl ?? openExternalUrl)(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(HomeStrings.unexpectedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradebookBackHeader(title: widget.courseTitle),
          Expanded(child: _buildBody()),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppDimens.screenPadding),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                16,
                AppDimens.screenPadding,
                0,
              ),
              child: TeacherPillButton(
                label: TeacherGradebookStrings.mentorFeedback,
                variant: TeacherPillVariant.filled,
                fontSize: 18,
                onPressed: null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final submission = _submission;
    final error = _error;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                style: AppTypography.cardSupporting,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: TeacherHomeStrings.retry,
                variant: AppButtonVariant.outlined,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    if (submission == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.blue,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        19,
        AppDimens.screenPadding,
        16,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: HomePalette.headerRule,
              width: AppDimens.borderWidthEmphasis,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tabs(
                selected: _tab,
                onSelect: (index) => setState(() => _tab = index),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.cardPadding),
                child: _tab == 0
                    ? _AssignmentTab(
                        submission: submission,
                        onOpenLink: _openLink,
                      )
                    : const Text(
                        TeacherGradebookStrings.noteUnavailable,
                        style: AppTypography.cardSupporting,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Assignment / Note: the selected label blue over a 2pt blue rule, the
/// card's hairline under both.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = [
      TeacherGradebookStrings.tabAssignment,
      TeacherGradebookStrings.tabNote,
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.headerRule)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppDimens.cardPadding),
        child: Row(
          children: [
            for (final (index, label) in labels.indexed)
              Semantics(
                button: true,
                selected: index == selected,
                child: GestureDetector(
                  onTap: () => onSelect(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: index == selected
                              ? HomePalette.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: index == selected ? _tabSelected : _tabStyle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentTab extends StatelessWidget {
  const _AssignmentTab({required this.submission, required this.onOpenLink});

  final TeacherSubmission submission;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final score = submission.score;
    final feedback = submission.feedback;
    final link = submission.link;
    final description = submission.description;
    final hasLink = link != null && link.isNotEmpty;
    final hasDescription = description != null && description.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLink)
          Semantics(
            link: true,
            label: link,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onOpenLink(link),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(
                    AppIcons.link,
                    size: 20,
                    color: GradebookColors.link,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      link,
                      style: _linkStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasDescription)
          Padding(
            padding: EdgeInsets.only(top: hasLink ? 24 : 8),
            child: _OutlinedBox(
              label: TeacherGradebookStrings.description,
              text: description,
            ),
          ),
        if (!hasLink && !hasDescription)
          Text(
            TeacherGradebookStrings.contentUnavailable,
            style: AppTypography.cardSupporting,
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StatusCapsule(submission: submission),
            if (submission.isReviewed && score != null) ...[
              const SizedBox(width: 12),
              Text(TeacherGradebookStrings.score(score), style: _scoreStyle),
            ],
          ],
        ),
        if (submission.isReviewed && feedback != null && feedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _OutlinedBox(
              label: TeacherGradebookStrings.mentorFeedback,
              text: feedback,
            ),
          ),
      ],
    );
  }
}

/// The reference's outlined box with its label on the outline — the
/// student's "Тайлбар", and the review's feedback.
class _OutlinedBox extends StatelessWidget {
  const _OutlinedBox({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: _boxLabel,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        border: _boxBorder,
        enabledBorder: _boxBorder,
      ),
      child: Text(text, style: _boxText),
    );
  }
}

/// Хүлээгдэж буй / Дүгнэгдсэн, as the filter chips name the two confirmed
/// statuses. Any other status is shown as sent.
class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule({required this.submission});

  final TeacherSubmission submission;

  @override
  Widget build(BuildContext context) {
    final label = submission.isReviewed
        ? TeacherGradebookStrings.filterGraded
        : submission.isPending
        ? TeacherGradebookStrings.filterPending
        : submission.status;
    final (outline, fill, ink) = submission.isReviewed
        ? (
            HomePalette.activeOutline,
            HomePalette.activeFill,
            HomePalette.activeInk,
          )
        : (
            HomePalette.mutedOutline,
            HomePalette.mutedFill,
            AppColors.textPrimary,
          );
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline),
      ),
      child: Text(label, style: _capsuleStyle.copyWith(color: ink)),
    );
  }
}

const OutlineInputBorder _boxBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: HomePalette.border),
);

final TextStyle _tabSelected = AppTypography.programTitle.copyWith(
  fontSize: 16,
  height: 22 / 16,
  fontWeight: FontWeight.w700,
  color: HomePalette.accent,
);

final TextStyle _tabStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 16,
  height: 22 / 16,
  fontWeight: FontWeight.w400,
  color: TeacherPillColors.ink,
);

final TextStyle _linkStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 16,
  height: 22 / 16,
  fontWeight: FontWeight.w500,
  color: GradebookColors.link,
  decoration: TextDecoration.underline,
  decorationColor: GradebookColors.link,
);

final TextStyle _scoreStyle = AppTypography.programTitle.copyWith(
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w700,
  color: TeacherPillColors.ink,
);

final TextStyle _capsuleStyle = AppTypography.catalogStatusLabel.copyWith(
  fontSize: 12,
  height: 16 / 12,
);

final TextStyle _boxLabel = AppTypography.cardSupporting.copyWith(
  fontSize: 14,
  color: TeacherPillColors.ink,
);

final TextStyle _boxText = AppTypography.cardSupporting.copyWith(
  fontSize: 16,
  height: 24 / 16,
  color: TeacherPillColors.ink,
);
