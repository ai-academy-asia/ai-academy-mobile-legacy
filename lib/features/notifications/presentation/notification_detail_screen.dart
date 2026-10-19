import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/app_notification.dart';
import '../../../shared/widgets/back_title_header.dart';
import '../../../shared/widgets/content_column.dart';
import 'notification_strings.dart';

/// One notification in full (Issue #248) — what a Notification Center row
/// opens, for every `kind`. The row holds one line of title and one of body;
/// this holds all of both, scrolling when they run long.
///
/// No Figma frame draws it: by product decision it is the Notification
/// Center's own header and language, with nothing new — top to bottom, a
/// centred metadata block (the row's bell in [AppPalette.accent] on a 48pt
/// [AppPalette.accentSubtle] disc, the title, the sent time), an
/// [AppPalette.divider] rule, then the body, left-aligned for reading on
/// an [AppPalette.pageBackground] ground — the app's own page grey, so a short
/// message reads as a section rather than a line floating on white. The body
/// never ends on a short word alone: see [bindShortLastWords].
///
/// Built from the [AppNotification] the list already loaded: the contract
/// has no detail endpoint, and nothing here changes. Read state stays with
/// `NotificationCenter`; `kind` and `data` are not read — no deep links are
/// defined.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({required this.notification, super.key});

  final AppNotification notification;

  /// Pushes the detail for [notification] over [context]'s navigator.
  static Future<void> open(
    BuildContext context,
    AppNotification notification,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NotificationDetailScreen(notification: notification),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: palette.surface),
      child: Scaffold(
        backgroundColor: palette.surface,
        body: SafeArea(
          bottom: false,
          // Capped at the content width, as every page is (Issue #368).
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BackTitleHeader(title: NotificationStrings.title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      _headerToContent,
                      AppDimens.screenPadding,
                      _contentBottom + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: _discSize,
                            height: _discSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.accentSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              HomeIcons.notification,
                              width: _iconSize,
                              height: _iconSize,
                              colorFilter: ColorFilter.mode(
                                palette.accent,
                                BlendMode.srcIn,
                              ),
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: _discToTitle),
                        Semantics(
                          header: true,
                          child: Text(
                            notification.title,
                            style: _titleStyle.copyWith(
                              color: palette.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: _titleToDate),
                        Text(
                          NotificationStrings.sentAt(notification.createdAt),
                          style: _dateStyle.copyWith(
                            color: palette.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: _metaToRule),
                        SizedBox(
                          height: AppDimens.borderWidth,
                          child: ColoredBox(color: palette.divider),
                        ),
                        // A title-only notification (Issue #451) has no body
                        // container at all — not an empty one.
                        if (notification.body case final body?) ...[
                          const SizedBox(height: _ruleToBody),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.pageBackground,
                              borderRadius: BorderRadius.circular(
                                AppDimens.cardRadius,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                AppDimens.cardPadding,
                              ),
                              child: Text(
                                bindShortLastWords(body),
                                style: _bodyStyle.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// --- No frame: the app's own spacing — `AppDimens` where it has the value,
// the Notification row's otherwise ----------------------------------------

/// A pushed page's header-to-content gap and bottom (Issue #368).
const double _headerToContent = AppDimens.pageContentTop;
const double _contentBottom = AppDimens.pageBottom;

/// The bell at the row's 24pt, on a 48pt disc — present, not dominant.
const double _discSize = 48;
const double _iconSize = 24;

/// The icon, the title and the time read as one block: [AppDimens.fieldGap]
/// under the disc, the row's own 4 between title and time.
const double _discToTitle = AppDimens.fieldGap;
const double _titleToDate = 4;

/// The rule sits a heading's gap from the metadata and from the body.
const double _metaToRule = AppDimens.headingToForm;
const double _ruleToBody = AppDimens.headingToForm;

/// The notification's title — the page's strongest text under the header.
const TextStyle _titleStyle = AppTypography.sectionTitle;

/// When it was sent, in the app's secondary ink.
const TextStyle _dateStyle = AppTypography.dateTime;

/// The notification's body, in the primary ink: here it is the thing being
/// read.
const TextStyle _bodyStyle = AppTypography.body;

/// [text] with each paragraph's last word bound to the one before it by a
/// no-break space, when that last word is short — so a body never ends on a
/// stray `үү.` alone. Flutter has no balanced or "pretty" wrap, and a
/// sentence a hair under the column's width (the device's own shaping can
/// add the hair) otherwise drops just its last word.
///
/// Only a last word of at most [maxShortWord] characters is bound, and only
/// when the pair is at most [maxPair] — short enough to sit on any line of
/// the column, so binding can never force a break inside a word. Spaces,
/// line breaks and every character are otherwise kept as sent.
@visibleForTesting
String bindShortLastWords(
  String text, {
  int maxShortWord = 4,
  int maxPair = 24,
}) => text
    .split('\n')
    .map((paragraph) {
      final end = paragraph.trimRight().length;
      if (end == 0) return paragraph;
      final lastSpace = paragraph.lastIndexOf(' ', end - 1);
      if (lastSpace <= 0) return paragraph;
      final previousSpace = paragraph.lastIndexOf(' ', lastSpace - 1);
      final lastWord = end - lastSpace - 1;
      final previousWord = lastSpace - previousSpace - 1;
      if (previousWord == 0 ||
          lastWord > maxShortWord ||
          previousWord + 1 + lastWord > maxPair) {
        return paragraph;
      }
      return '${paragraph.substring(0, lastSpace)}\u00A0'
          '${paragraph.substring(lastSpace + 1)}';
    })
    .join('\n');
