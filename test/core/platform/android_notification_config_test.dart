import 'dart:io';

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Android side of push notifications (Issue #425): the manifest's
/// Firebase defaults, the resources they name, the channel MainActivity
/// creates, the monochrome small icon, and the release-signing rules. Native
/// code does not run in these tests, so they pin the wiring between files.
void main() {
  const res = 'android/app/src/main/res';
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final strings = File('$res/values/strings.xml').readAsStringSync();
  final colors = File('$res/values/colors.xml').readAsStringSync();
  final icon = File(
    '$res/drawable/ic_stat_notification.xml',
  ).readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/aiacademyasia/aia_mobile/MainActivity.kt',
  ).readAsStringSync();

  /// The `android:value` or `android:resource` of a manifest meta-data entry.
  String? metaData(String name) => RegExp(
    '<meta-data\\s+android:name="${RegExp.escape(name)}"\\s+'
    'android:(?:value|resource)="([^"]+)"',
  ).firstMatch(manifest)?.group(1);

  String? resourceValue(String xml, String type, String name) => RegExp(
    '<$type name="${RegExp.escape(name)}"[^>]*>([^<]*)</$type>',
  ).firstMatch(xml)?.group(1);

  group('the manifest names Firebase defaults that exist', () {
    test('channel id → @string/default_notification_channel_id', () {
      expect(
        metaData(
          'com.google.firebase.messaging.default_notification_channel_id',
        ),
        '@string/default_notification_channel_id',
      );
      expect(
        resourceValue(strings, 'string', 'default_notification_channel_id'),
        isNotEmpty,
      );
    });

    test(
      'small icon → @drawable/ic_stat_notification, never the launcher icon',
      () {
        expect(
          metaData('com.google.firebase.messaging.default_notification_icon'),
          '@drawable/ic_stat_notification',
        );
      },
    );

    test('accent → @color/notification_accent, the theme primary', () {
      expect(
        metaData('com.google.firebase.messaging.default_notification_color'),
        '@color/notification_accent',
      );
      final hex = AppColors.blue
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
      expect(resourceValue(colors, 'color', 'notification_accent'), '#$hex');
    });
  });

  group('the default channel', () {
    test('is named "Мэдэгдэл"', () {
      expect(
        resourceValue(strings, 'string', 'default_notification_channel_name'),
        'Мэдэгдэл',
      );
    });

    test('is created by MainActivity from those strings, default importance, '
        'API 26+ only', () {
      expect(activity, contains('R.string.default_notification_channel_id'));
      expect(activity, contains('R.string.default_notification_channel_name'));
      expect(activity, contains('NotificationManager.IMPORTANCE_DEFAULT'));
      expect(activity, contains('Build.VERSION_CODES.O'));
      expect(activity, contains('createNotificationChannel('));
    });
  });

  group('the small icon', () {
    test('draws in white only: Android reads a small icon\'s alpha alone', () {
      final paints = RegExp(
        r'android:(?:strokeColor|fillColor)="([^"]+)"',
      ).allMatches(icon).map((m) => m.group(1)!.toUpperCase()).toSet();
      expect(paints, isNotEmpty);
      expect(paints.difference({'#FFFFFFFF', '#FFFFFF'}), isEmpty);
    });

    test(
      'is the in-app bell, assets/icons/notification.svg, path for path',
      () {
        final bell = File('assets/icons/notification.svg').readAsStringSync();
        final svgPaths = RegExp(
          r' d="([^"]+)"',
        ).allMatches(bell).map((m) => m.group(1));
        final vectorPaths = RegExp(
          r'android:pathData="([^"]+)"',
        ).allMatches(icon).map((m) => m.group(1));
        expect(vectorPaths.toList(), svgPaths.toList());
      },
    );
  });

  group('release signing', () {
    test('keystores and key.properties stay out of git', () {
      final ignore = File('android/.gitignore').readAsLinesSync();
      expect(
        ignore,
        containsAll(['key.properties', '**/*.keystore', '**/*.jks']),
      );
    });

    test('an App Bundle refuses to build without android/key.properties', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('"bundleRelease" in tasks'));
      expect(
        gradle,
        contains('an App Bundle is never signed with the debug keys'),
      );
    });
  });
}
