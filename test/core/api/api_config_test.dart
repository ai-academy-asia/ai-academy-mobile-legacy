import 'dart:io';

import 'package:aia_mobile/core/api/api_config.dart';
import 'package:aia_mobile/core/api/api_override_banner.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The debug-only API base-URL override (Issue #388). No request is made:
/// only how the base URL is resolved, and that every repository takes it.
void main() {
  final production = Uri.parse('https://api.ai-academy.asia');

  group('debug builds (allowOverride: true)', () {
    test('no define: production', () {
      final api = ApiConfig.resolve('', allowOverride: true);
      expect(api.uri, production);
      expect(api.isOverride, isFalse);
    });

    test('a local URL is used, marked as an override', () {
      final api = ApiConfig.resolve(
        'http://localhost:8000',
        allowOverride: true,
      );
      expect(api.uri, Uri.parse('http://localhost:8000'));
      expect(api.isOverride, isTrue);
      expect(api.label, 'localhost:8000');
    });

    test('a LAN address with a trailing slash and spaces is the origin', () {
      final api = ApiConfig.resolve(
        '  http://192.168.1.20:8000/ ',
        allowOverride: true,
      );
      expect(api.uri, Uri.parse('http://192.168.1.20:8000'));
      expect(api.label, '192.168.1.20:8000');
    });

    test('the production URL itself is not an override', () {
      expect(
        ApiConfig.resolve(
          'https://api.ai-academy.asia/',
          allowOverride: true,
        ).isOverride,
        isFalse,
      );
    });

    for (final (name, value) in [
      ('no scheme', 'localhost:8000'),
      ('another scheme', 'ftp://localhost:8000'),
      ('no host', 'http://'),
      ('not a URL', 'not a url'),
      ('credentials', 'http://dev:s3cret-pass@localhost:8000'),
      ('a path', 'http://localhost:8000/api'),
      ('a query', 'http://localhost:8000?debug=1'),
      ('a fragment', 'http://localhost:8000#x'),
    ]) {
      test('$name is refused — never a silent fallback to production', () {
        try {
          ApiConfig.resolve(value, allowOverride: true);
          fail('expected InvalidApiBaseUrl');
        } on InvalidApiBaseUrl catch (error) {
          // The message names the rule, never the value — except where the
          // value is part of the message's own fixed example
          // ("http://localhost:8000"), which echoes nothing.
          final message = error.toString();
          expect(message.contains('s3cret-pass'), isFalse);
          const example = 'http://localhost:8000';
          if (!example.contains(value)) {
            expect(message.contains(value), isFalse);
          }
        }
      });
    }
  });

  group('release and profile builds (allowOverride: false)', () {
    for (final value in [
      'http://localhost:8000',
      'http://192.168.1.20:8000',
      'ftp://anything',
      'not a url',
    ]) {
      test('"$value" is ignored: production, no error', () {
        final api = ApiConfig.resolve(value, allowOverride: false);
        expect(api.uri, production);
        expect(api.isOverride, isFalse);
      });
    }

    test('the app resolves with kDebugMode — release can never override', () {
      final source = File('lib/core/api/api_config.dart').readAsStringSync();
      expect(source, contains('allowOverride: kDebugMode'));
      expect(source, contains("String.fromEnvironment(defineName)"));
    });
  });

  test('this test run has no override: production', () {
    expect(kDebugMode, isTrue);
    expect(ApiConfig.current.isOverride, isFalse);
    expect(ApiConfig.baseUrl, production);
  });

  test('every HTTP repository defaults to ApiConfig.baseUrl; no production '
      'URL is hard-coded anywhere else', () {
    final repositories = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            RegExp(r'/data/http_\w+_repository\.dart$').hasMatch(entity.path))
          entity,
    ];
    // 17 since `HttpScheduleChangeRepository` (Issue #449).
    expect(repositories, hasLength(17));
    for (final file in repositories) {
      final source = file.readAsStringSync();
      expect(source, contains('ApiConfig.baseUrl'), reason: file.path);
      expect(source, isNot(contains('defaultBaseUrl')), reason: file.path);
    }

    final literal = RegExp(r"""['"]https://api\.ai-academy\.asia""");
    final offenders = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('core/api/api_config.dart') &&
            literal.hasMatch(entity.readAsStringSync()))
          entity.path,
    ];
    expect(offenders, isEmpty);
  });

  testWidgets('the override marker names host:port and takes no taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApiOverrideBanner(
          label: 'localhost:8000',
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 300,
                height: 200,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('under'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('API: localhost:8000'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('API: localhost:8000')));
    expect(taps, 1);
  });
}
