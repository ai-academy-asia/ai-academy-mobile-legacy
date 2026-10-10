import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_signature_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The E-Contract signature pad (Issue #304): drawing, Clear, the PNG it
/// exports, and that a stroke never scrolls the page. No API is involved.
void main() {
  setUpAll(loadAppFonts);

  late ContractSignatureController controller;

  setUp(() => controller = ContractSignatureController());
  tearDown(() => controller.dispose());

  /// The pad on a phone-width page; [scrollable] puts it inside a tall
  /// scroll view, [theme] picks the palette.
  Future<void> pump(
    WidgetTester tester, {
    bool scrollable = false,
    ThemeData? theme,
    ScrollController? scroll,
  }) async {
    useLogicalViewport(tester, const Size(393, 852));
    final pad = Padding(
      padding: const EdgeInsets.all(16),
      child: ContractSignaturePad(controller: controller),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: scrollable
              ? SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(height: 200),
                      pad,
                      const SizedBox(height: 1200),
                    ],
                  ),
                )
              : pad,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder padArea() => find.bySemanticsLabel(ContractStrings.signHere);
  Finder clear() => find.bySemanticsLabel(ContractStrings.clear);

  Color clearColour(WidgetTester tester) =>
      tester.widget<Text>(find.text(ContractStrings.clear)).style!.color!;

  /// A short stroke across the middle of the pad.
  Future<void> sign(WidgetTester tester) async {
    final centre = tester.getCenter(padArea());
    final gesture = await tester.startGesture(centre - const Offset(60, 0));
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(20, i.isEven ? 12 : -12));
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('draws the title, the pad and Clear', (tester) async {
    await pump(tester);

    expect(find.text(ContractStrings.signHere), findsOneWidget);
    expect(padArea(), findsOneWidget);
    expect(find.text(ContractStrings.clear), findsOneWidget);
    expect(tester.getSize(padArea()).height, 158);
  });

  testWidgets('starts empty, with Clear disabled', (tester) async {
    await pump(tester);

    expect(controller.isEmpty, isTrue);
    expect(
      tester.getSemantics(clear()),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        label: 'Цэвэрлэх / Clear',
      ),
    );
    expect(clearColour(tester), AppPalette.light.disabledInk);
  });

  testWidgets('a drag draws, and Clear empties it again', (tester) async {
    await pump(tester);

    await sign(tester);
    expect(controller.isEmpty, isFalse);
    expect(controller.strokeCount, 1);
    expect(clearColour(tester), AppPalette.light.accentText);

    await tester.tap(clear());
    await tester.pump();

    expect(controller.isEmpty, isTrue);
    expect(clearColour(tester), AppPalette.light.disabledInk);
  });

  testWidgets('a tap is a dot — something drawn', (tester) async {
    await pump(tester);

    await tester.tapAt(tester.getCenter(padArea()));
    await tester.pump();

    expect(controller.isEmpty, isFalse);
    expect(controller.strokeCount, 1);
  });

  testWidgets('each lift starts a new stroke', (tester) async {
    await pump(tester);

    await sign(tester);
    await sign(tester);

    expect(controller.strokeCount, 2);
  });

  testWidgets('a stroke that leaves the pad keeps only its points inside, '
      'and re-entering starts a new stroke', (tester) async {
    await pump(tester);
    final rect = tester.getRect(padArea());

    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(rect.center + const Offset(30, 0));
    // Out below the pad, then back in.
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom + 60));
    await gesture.moveTo(rect.center - const Offset(30, 0));
    await gesture.moveTo(rect.center - const Offset(60, 10));
    await gesture.up();
    await tester.pump();

    expect(controller.strokeCount, 2);
  });

  testWidgets('a drag on the pad never scrolls the page; outside it does', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pump(tester, scrollable: true, scroll: scroll);

    await tester.drag(padArea(), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(controller.isEmpty, isFalse);

    // The control: the same drag above the pad scrolls.
    await tester.dragFrom(const Offset(196, 100), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  });

  group('toPng', () {
    testWidgets('is null while nothing is drawn', (tester) async {
      await pump(tester);

      expect(await tester.runAsync(controller.toPng), isNull);
    });

    testWidgets('is a PNG at twice the pad size, under the backend\'s '
        '0.6 megapixels', (tester) async {
      await pump(tester);
      await sign(tester);

      final png = (await tester.runAsync(controller.toPng))!;
      // The canvas is the pad inside its border.
      final pad = tester.getSize(padArea());
      final canvas = Size(
        pad.width - 2 * AppDimens.borderWidth,
        pad.height - 2 * AppDimens.borderWidth,
      );

      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(png, 16, 24);
      final width = header.getUint32(0);
      final height = header.getUint32(4);
      expect(width, (canvas.width * 2).floor());
      expect(height, (canvas.height * 2).floor());
      expect(width * height, lessThanOrEqualTo(600000));
      expect(png.length, lessThan(2 * 1024 * 1024));
    });

    testWidgets('a cleared pad exports nothing', (tester) async {
      await pump(tester);
      await sign(tester);
      controller.clear();

      expect(await tester.runAsync(controller.toPng), isNull);
    });

    testWidgets('is drawn in the dark ink on a transparent background, '
        'whatever the theme', (tester) async {
      await pump(tester, theme: AppTheme.dark);
      await sign(tester);

      final pixels = (await tester.runAsync(() async {
        final png = await controller.toPng();
        final codec = await ui.instantiateImageCodec(png!);
        final image = (await codec.getNextFrame()).image;
        final data = await image.toByteData();
        image.dispose();
        return data!;
      }))!;

      var inked = 0;
      var transparent = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        final alpha = pixels.getUint8(i + 3);
        if (alpha == 0) {
          transparent++;
        } else if (alpha == 255) {
          inked++;
          expect(
            Color.fromARGB(
              255,
              pixels.getUint8(i),
              pixels.getUint8(i + 1),
              pixels.getUint8(i + 2),
            ),
            AppColors.linkInk,
          );
        }
      }
      expect(inked, greaterThan(0));
      expect(transparent, greaterThan(inked));
    });
  });
}
