import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/data/http_course_learning_repository.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../../course_learning/presentation/widgets/certificate_preview.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../course_learning/presentation/widgets/course_progress_cta_row.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../data/enrolled_certificate_list_repository.dart';
import '../domain/certificate_entry.dart';
import '../domain/certificate_list_repository.dart';
import 'certificate_list_controller.dart';
import 'certificate_strings.dart';

/// The student's certificates — the Figma "Certificate" frame (Issue #155):
/// one card per enrolled cohort, each the certificate artwork over the
/// cohort's name and course, then one of the frame's two states:
///
///  * **issued** (§2.9 `status: issued`) — "Completed date:" with the
///    certificate's `issued_at`, and Download, which fetches a fresh
///    pre-signed link (`GET /me/certificates/{cert_number}/download`) and
///    opens it outside the app;
///  * **not yet issued** (`not_eligible`, `eligible`, or a status this build
///    does not know) — the course's progress and "Continue learning", which
///    opens the course's Module List.
///
/// The state is the server's `status`, never computed here. `eligible`
/// (requirements met, certificate not issued yet) has no state of its own in
/// the frame, so it draws as not yet issued (a `PRODUCT DECISION`, #155);
/// the `requirements` list and `verify_url` are not drawn — no design.
///
/// Reached from the "Certificate" row of both student Profiles — Adult and
/// Junior — through [CertificateScreen.open]. A Junior student is a student
/// in kids mode (`user_type: child`), on the same student token and the same
/// `/me/...` endpoints Junior Home already reads, so both see the same cards;
/// "Continue learning" opens the course's Module List, which Junior Home's
/// own course card opens too (Issues #174, #207). There is no Junior-specific
/// certificate frame. The artwork is the same for every student
/// ([CertificatePreview]).
class CertificateScreen extends StatefulWidget {
  const CertificateScreen({
    super.key,
    this.repository,
    this.courseLearning,
    this.openUrl,
  });

  /// The cards. Defaults to the real composition over the API. Injected in
  /// tests.
  final CertificateListRepository? repository;

  /// For the download link, and for the Module List "Continue learning"
  /// opens. Defaults to the real API. Injected in tests.
  final CourseLearningRepository? courseLearning;

  /// Opens the download link. Defaults to `openExternalUrl`. Injected in
  /// tests.
  final Future<bool> Function(Uri url)? openUrl;

  /// Pushes the screen over [context]'s navigator — what both Profiles'
  /// "Certificate" rows do. [repository] and [courseLearning] default to the
  /// real API; the Profiles pass theirs through so tests can inject fakes.
  static Future<void> open(
    BuildContext context, {
    CertificateListRepository? repository,
    CourseLearningRepository? courseLearning,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CertificateScreen(
        repository: repository,
        courseLearning: courseLearning,
      ),
    ),
  );

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  late final CourseLearningRepository _courseLearning =
      widget.courseLearning ?? HttpCourseLearningRepository();
  late final CertificateListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CertificateListController(
      repository:
          widget.repository ??
          EnrolledCertificateListRepository(courseLearning: _courseLearning),
      courseLearning: _courseLearning,
      openUrl: widget.openUrl,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(String certNumber) async {
    final error = await _controller.download(certNumber);
    if (error == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(error)));
  }

  void _continueLearning(String courseSlug) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CourseModuleListScreen(
        courseSlug: courseSlug,
        repository: _courseLearning,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _body(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!_controller.hasLoadedOnce || _controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final message = _controller.errorMessage;
    if (message != null) {
      return _Message(
        message: message,
        action: TextButton(
          onPressed: _controller.load,
          child: const Text(CertificateStrings.retry),
        ),
      );
    }
    final entries = _controller.entries;
    if (entries.isEmpty) {
      return const _Message(message: CertificateStrings.empty);
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        _headerToCard,
        AppDimens.screenPadding,
        AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final certNumber = entry.certificate.issued?.certNumber;
        return _CertificateCard(
          entry: entry,
          downloading:
              certNumber != null && _controller.isDownloading(certNumber),
          onDownload: certNumber == null ? null : () => _download(certNumber),
          onContinue: () => _continueLearning(entry.courseSlug),
        );
      },
    );
  }
}

/// The back button with "Certificate" centred on its row.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const CourseLearningBackButton(icon: AppIcons.arrowLeft),
        Positioned.fill(
          // The button's own 12 above it, so the title centres on the circle.
          top: _backButtonTop,
          child: const Center(
            child: Text(
              CertificateStrings.title,
              style: _titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.entry,
    required this.downloading,
    required this.onDownload,
    required this.onContinue,
  });

  final CertificateEntry entry;
  final bool downloading;
  final VoidCallback? onDownload;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final certificate = entry.certificate;
    final issuedAt = certificate.issued?.issuedAt;
    final percent = entry.progressPercent;

    return Container(
      // The border's width comes off the padding: `Container` adds it on
      // top, and the frame puts the content 16 inside the card's outer edge.
      padding: const EdgeInsets.all(
        AppDimens.cardPadding - AppDimens.borderWidth,
      ),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: _cardBorder, width: AppDimens.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CertificatePreview(inset: _artworkInset, outlined: true),
          const SizedBox(height: _previewToCaption),
          Text(
            entry.cohortName,
            style: _captionStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: _captionToTitle),
          Text(
            entry.courseTitle,
            style: _cardTitleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (certificate.isIssued) ...[
            if (issuedAt != null) ...[
              const SizedBox(height: _titleToDate),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      CertificateStrings.completedDate,
                      style: _dateStyle,
                    ),
                  ),
                  Text(CertificateStrings.date(issuedAt), style: _dateStyle),
                ],
              ),
            ],
            const SizedBox(height: _dateToDownload),
            _DownloadButton(downloading: downloading, onPressed: onDownload),
          ] else ...[
            const SizedBox(height: _titleToProgress),
            if (percent != null)
              CourseProgressCtaRow(
                percent: percent,
                buttonWidth: _ctaWidth,
                onContinue: onContinue,
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: ContinueLearningButton(
                  width: _ctaWidth,
                  onTap: onContinue,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The outlined Download pill: white, the border grey, the download glyph
/// lesson materials use beside the label. Busy while its link is fetched,
/// and inert then — a second tap does nothing.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.downloading, required this.onPressed});

  final bool downloading;

  /// Null when the issued certificate carried no number to download with.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder(side: BorderSide(color: HomePalette.border));
    // Its own node — one "Download" button to a screen reader, busy or not.
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null && !downloading,
      label: CertificateStrings.download,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: downloading ? null : onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: _downloadHeight,
            child: Center(
              child: downloading
                  ? const SizedBox.square(
                      dimension: _downloadIcon,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.blue,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          _downloadGlyph,
                          width: _downloadIcon,
                          height: _downloadIcon,
                        ),
                        const SizedBox(width: _iconToLabel),
                        const Text(
                          CertificateStrings.download,
                          style: _downloadStyle,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The loading-failed and empty states: one centred line, and a retry when
/// there is something to retry.
class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.statLabel,
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: AppDimens.fieldGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

// --- Measured off the Figma "Certificate" frame at 1:1 (393 wide, a 44pt
// status-bar inset) -----------------------------------------------------------

/// `CourseLearningBackButton`'s own inset above the circle.
const double _backButtonTop = 12;

/// The circle's bottom to the first card's top.
const double _headerToCard = 28;

const double _cardGap = 12;

/// The card: the Module List certification panel's fill and outline.
const Color _cardFill = Color(0xFFF9FAFB);
const Color _cardBorder = HomePalette.headerRule;

/// The certificate 12 inside its gradient frame, as this frame draws it.
const double _artworkInset = 12;

const double _previewToCaption = 17;
const double _captionToTitle = 1;
const double _titleToDate = 1;
const double _dateToDownload = 17;
const double _titleToProgress = 16;

/// "Continue learning" — the Module List certification panel's width, on
/// the same x213.
const double _ctaWidth = 148;

const double _downloadHeight = 40;
const double _downloadIcon = 20;
const double _iconToLabel = 6;
const String _downloadGlyph =
    'assets/images/course_learning/exercise_download.svg';

/// Ink: the Module List frame's two text greys.
const Color _primaryInk = Color(0xFF191919);
const Color _secondaryInk = Color(0xFF7D7D7E);

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  color: _primaryInk,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _captionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w400,
  color: _secondaryInk,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _cardTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  color: _primaryInk,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _dateStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w400,
  color: _secondaryInk,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _downloadStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);
