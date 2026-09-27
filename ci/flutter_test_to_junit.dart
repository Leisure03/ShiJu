import 'dart:convert';
import 'dart:io';

/// 将 `flutter test --file-reporter=json:...` 输出的 JSON Lines 测试报告转换为
/// Jenkins `junit` 插件可直接解析的标准 JUnit XML 格式。
///
/// 用法:
///   `dart run ci/flutter_test_to_junit.dart <input_json_path> <output_xml_path>`
void main(List<String> args) {
  final String inputPath = args.isNotEmpty
      ? args[0]
      : 'build/reports/test-results.json';
  final String outputPath = args.length > 1
      ? args[1]
      : 'build/reports/junit-report.xml';

  final File inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('[JUnit Converter] 未找到测试结果 JSON 文件: $inputPath');
    exit(1);
  }

  final Map<int, String> suitePaths = <int, String>{};
  final Map<int, _TestCaseRecord> tests = <int, _TestCaseRecord>{};

  final List<String> lines = inputFile.readAsLinesSync();
  for (final String rawLine in lines) {
    final String line = rawLine.trim();
    if (line.isEmpty || !line.startsWith('{')) {
      continue;
    }

    Map<String, dynamic> event;
    try {
      final Object? decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      event = decoded;
    } catch (_) {
      continue;
    }

    final String? type = event['type'] as String?;
    final int timeMs = (event['time'] as num?)?.toInt() ?? 0;

    switch (type) {
      case 'suite':
        final Map<String, dynamic>? suite =
            event['suite'] as Map<String, dynamic>?;
        if (suite != null) {
          final int? id = (suite['id'] as num?)?.toInt();
          final String? path = suite['path'] as String?;
          if (id != null && path != null) {
            suitePaths[id] = path;
          }
        }
      case 'testStart':
        final Map<String, dynamic>? test =
            event['test'] as Map<String, dynamic>?;
        if (test != null) {
          final int? id = (test['id'] as num?)?.toInt();
          final String name = (test['name'] as String?) ?? 'unknown';
          final int? suiteId = (test['suiteID'] as num?)?.toInt();
          if (id != null) {
            tests[id] = _TestCaseRecord(
              id: id,
              name: name,
              suiteId: suiteId ?? 0,
              startTimeMs: timeMs,
            );
          }
        }
      case 'print':
        final int? testId = (event['testID'] as num?)?.toInt();
        final String? message = event['message'] as String?;
        if (testId != null && message != null) {
          tests[testId]?.logs.add(message);
        }
      case 'error':
        final int? testId = (event['testID'] as num?)?.toInt();
        final String error = (event['error'] as String?) ?? 'Unknown error';
        final String stackTrace = (event['stackTrace'] as String?) ?? '';
        if (testId != null) {
          final _TestCaseRecord? record = tests[testId];
          if (record != null) {
            record.errors.add(
              stackTrace.isNotEmpty ? '$error\n$stackTrace' : error,
            );
          }
        }
      case 'testDone':
        final int? testId = (event['testID'] as num?)?.toInt();
        final bool hidden = (event['hidden'] as bool?) ?? false;
        final bool skipped = (event['skipped'] as bool?) ?? false;
        final String result = (event['result'] as String?) ?? 'success';
        if (testId != null) {
          final _TestCaseRecord? record = tests[testId];
          if (record != null) {
            record.endTimeMs = timeMs;
            record.hidden = hidden;
            record.skipped = skipped;
            record.result = result;
          }
        }
    }
  }

  // 过滤掉 loading 等隐藏内部事件
  final List<_TestCaseRecord> visibleTests = tests.values
      .where((_TestCaseRecord t) => !t.hidden && !t.name.startsWith('loading '))
      .toList();

  final Map<int, List<_TestCaseRecord>> groupedBySuite =
      <int, List<_TestCaseRecord>>{};
  for (final _TestCaseRecord test in visibleTests) {
    groupedBySuite
        .putIfAbsent(test.suiteId, () => <_TestCaseRecord>[])
        .add(test);
  }

  int totalTests = 0;
  int totalFailures = 0;
  int totalSkipped = 0;
  double totalTimeSeconds = 0.0;

  final StringBuffer xml = StringBuffer();
  xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');

  final StringBuffer suitesXml = StringBuffer();
  for (final MapEntry<int, List<_TestCaseRecord>> entry
      in groupedBySuite.entries) {
    final String rawSuitePath = suitePaths[entry.key] ?? 'flutter_test_suite';
    final String suiteName = _normalizeSuiteName(rawSuitePath);
    final List<_TestCaseRecord> suiteTests = entry.value;

    int suiteFailures = 0;
    int suiteSkipped = 0;
    double suiteTimeSec = 0.0;

    final StringBuffer casesXml = StringBuffer();
    for (final _TestCaseRecord tc in suiteTests) {
      final double durationSec = tc.durationSeconds;
      suiteTimeSec += durationSec;
      totalTests++;

      final bool isFailed = tc.result != 'success' || tc.errors.isNotEmpty;
      if (tc.skipped) {
        suiteSkipped++;
        totalSkipped++;
      } else if (isFailed) {
        suiteFailures++;
        totalFailures++;
      }

      casesXml.writeln(
        '    <testcase classname="${_escapeXml(suiteName)}" '
        'name="${_escapeXml(tc.name)}" '
        'time="${durationSec.toStringAsFixed(3)}">',
      );

      if (tc.skipped) {
        casesXml.writeln('      <skipped/>');
      } else if (isFailed) {
        final String fullError = tc.errors.isNotEmpty
            ? tc.errors.join('\n\n')
            : 'Test failed with result: ${tc.result}';
        final String firstLine = fullError.split('\n').first;
        casesXml.writeln(
          '      <failure message="${_escapeXml(firstLine)}">'
          '${_escapeXml(fullError)}</failure>',
        );
      }

      if (tc.logs.isNotEmpty) {
        casesXml.writeln(
          '      <system-out>${_escapeXml(tc.logs.join('\n'))}</system-out>',
        );
      }

      casesXml.writeln('    </testcase>');
    }

    totalTimeSeconds += suiteTimeSec;
    suitesXml.writeln(
      '  <testsuite name="${_escapeXml(suiteName)}" '
      'tests="${suiteTests.length}" '
      'failures="$suiteFailures" '
      'errors="0" '
      'skipped="$suiteSkipped" '
      'time="${suiteTimeSec.toStringAsFixed(3)}">',
    );
    suitesXml.write(casesXml.toString());
    suitesXml.writeln('  </testsuite>');
  }

  xml.writeln(
    '<testsuites name="ShiJu Flutter Tests" '
    'tests="$totalTests" '
    'failures="$totalFailures" '
    'errors="0" '
    'skipped="$totalSkipped" '
    'time="${totalTimeSeconds.toStringAsFixed(3)}">',
  );
  xml.write(suitesXml.toString());
  xml.writeln('</testsuites>');

  final File outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(xml.toString(), flush: true);

  stdout.writeln(
    '[JUnit Converter] 已生成 JUnit XML 报告: $outputPath '
    '(共 $totalTests 个用例, 失败 $totalFailures, 跳过 $totalSkipped)',
  );
}

String _normalizeSuiteName(String rawPath) {
  final String normalized = rawPath.replaceAll('\\', '/');
  final int testIdx = normalized.lastIndexOf('/test/');
  if (testIdx >= 0) {
    return normalized.substring(testIdx + 1);
  }
  return normalized;
}

String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class _TestCaseRecord {
  _TestCaseRecord({
    required this.id,
    required this.name,
    required this.suiteId,
    required this.startTimeMs,
  });

  final int id;
  final String name;
  final int suiteId;
  final int startTimeMs;
  int endTimeMs = 0;
  bool hidden = false;
  bool skipped = false;
  String result = 'success';
  final List<String> errors = <String>[];
  final List<String> logs = <String>[];

  double get durationSeconds {
    final int deltaMs = endTimeMs - startTimeMs;
    if (deltaMs <= 0) {
      return 0.0;
    }
    return deltaMs / 1000.0;
  }
}
