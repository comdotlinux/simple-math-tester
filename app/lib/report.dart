import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What one report request came to. A new issue (201) and an issue that
/// already existed (200) both count as sent: the player is thanked the same
/// way. Every other answer, a timeout and no connection fail alike, and the
/// mark stays on the device.
enum ReportOutcome { sent, failed }

/// The report function (issue #149, `functions/api/report.js`). The web app
/// asks its own origin; the other builds ask the production site.
final Uri reportEndpoint = kIsWeb
    ? Uri.base.resolve('/api/report')
    : Uri.parse('https://math.munich-tech.de/api/report');

/// The one request the app can make: a report a grown-up chose to send.
abstract interface class ReportClient {
  /// Posts [body], the report as JSON, exactly once: no retry, no queue,
  /// nothing sent later on its own.
  Future<ReportOutcome> send(String body);
}

class HttpReportClient implements ReportClient {
  /// [client] is for tests; the app makes a new one per report.
  HttpReportClient([this._client]);

  final http.Client? _client;

  static const timeout = Duration(seconds: 15);

  @override
  Future<ReportOutcome> send(String body) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            reportEndpoint,
            headers: const {'content-type': 'application/json'},
            body: body,
          )
          .timeout(timeout);
      return switch (response.statusCode) {
        201 || 200 => ReportOutcome.sent,
        _ => ReportOutcome.failed,
      };
    } catch (_) {
      return ReportOutcome.failed;
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// The reasons a question report can give, by their contract names; a
/// drawing can be wrong only in geometry.
List<String> questionReasons(String kind) => [
  'wrongAnswer',
  'unclearQuestion',
  'wrongHint',
  if (kind == 'geometry') 'wrongDrawing',
];

/// The categories a problem report can give, by their contract names.
const problemCategories = ['crash', 'display', 'sound', 'translation', 'other'];

/// The platform as the contract names it.
String get reportPlatform =>
    kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
