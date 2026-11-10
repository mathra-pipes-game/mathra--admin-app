import 'dart:convert';
import 'dart:io';

import 'package:mathra_admin/firebase_config.dart';

class CloudException implements Exception {
  CloudException(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'Cloud $status: $body';
}

/// One filter of a Firestore query: field OP value.
class CloudFilter {
  const CloudFilter(this.field, this.op, this.value);
  final String field;

  /// EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, LESS_THAN ...
  final String op;
  final Object value;
}

/// Tiny Firestore REST client (no extra packages).
/// SAME FILE is used by the game and by the admin app.
///  * Game  -> no [idToken]  (public, rules-limited access)
///  * Admin -> [idToken] from Firebase Auth login (full access)
class CloudClient {
  CloudClient({this.idToken});

  String? idToken;

  /// Server time minus phone time (from the HTTP "Date" header).
  static int serverOffsetMs = 0;
  static bool hasServerTime = false;

  /// Best guess of the real current time (server clock when known).
  static DateTime serverNow() => hasServerTime
      ? DateTime.now().add(Duration(milliseconds: serverOffsetMs))
      : DateTime.now();

  static String get docsRoot =>
      'projects/${FirebaseConfig.projectId}/databases/(default)/documents';
  static String get _base => 'https://firestore.googleapis.com/v1/$docsRoot';
  static String get _key => 'key=${FirebaseConfig.apiKey}';

  // ───────────── value encoding ─────────────

  static Map<String, dynamic> encodeValue(Object? v) {
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v == null) return {'nullValue': null};
    return {'stringValue': '$v'};
  }

  static Object? decodeValue(Map v) {
    if (v.containsKey('integerValue')) {
      return int.tryParse('${v['integerValue']}') ?? 0;
    }
    if (v.containsKey('stringValue')) return '${v['stringValue']}';
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    return null;
  }

  static Map<String, dynamic> encodeFields(Map<String, Object?> data) =>
      {for (final e in data.entries) e.key: encodeValue(e.value)};

  /// Firestore document -> plain map (+ '_id' = document id).
  static Map<String, dynamic> decodeDoc(Map doc) {
    final out = <String, dynamic>{};
    final name = '${doc['name'] ?? ''}';
    out['_id'] = name.contains('/') ? name.substring(name.lastIndexOf('/') + 1) : name;
    final f = doc['fields'];
    if (f is Map) {
      for (final e in f.entries) {
        if (e.value is Map) out['${e.key}'] = decodeValue(e.value as Map);
      }
    }
    return out;
  }

  // ───────────── http ─────────────

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final sep = path.contains('?') ? '&' : '?';
    final url = '$_base$path$sep$_key';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.openUrl(method, Uri.parse(url));
      req.headers.contentType = ContentType.json;
      final t = idToken;
      if (t != null) req.headers.set('Authorization', 'Bearer $t');
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      final date = res.headers.value('date');
      if (date != null) {
        try {
          final d = HttpDate.parse(date);
          serverOffsetMs =
              d.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
          hasServerTime = true;
        } catch (_) {}
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw CloudException(res.statusCode, text);
      }
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  // ───────────── documents ─────────────

  /// Reads one document. Returns null when it does not exist.
  Future<Map<String, dynamic>?> getDoc(String path) async {
    try {
      final r = await _send('GET', '/$path');
      if (r is Map) return decodeDoc(r);
      return null;
    } on CloudException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Creates / updates only the given fields.
  Future<void> patchDoc(String path, Map<String, Object?> data) async {
    final mask = data.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');
    await _send('PATCH', '/$path?$mask', {'fields': encodeFields(data)});
  }

  Future<void> deleteDoc(String path) async {
    await _send('DELETE', '/$path');
  }

  /// One "write" for [commit]: set fields, optionally +increment counters.
  static Map<String, dynamic> writeUpdate(
    String path,
    Map<String, Object?> data, {
    Map<String, int> increments = const {},
  }) {
    return {
      'update': {
        'name': '$docsRoot/$path',
        'fields': encodeFields(data),
      },
      'updateMask': {'fieldPaths': data.keys.toList()},
      if (increments.isNotEmpty)
        'updateTransforms': [
          for (final e in increments.entries)
            {
              'fieldPath': e.key,
              'increment': {'integerValue': '${e.value}'},
            }
        ],
    };
  }

  /// Several writes, all-or-nothing.
  Future<void> commit(List<Map<String, dynamic>> writes) async {
    await _send('POST', ':commit', {'writes': writes});
  }

  // ───────────── queries ─────────────

  Map<String, dynamic>? _where(List<CloudFilter> filters) {
    if (filters.isEmpty) return null;
    Map<String, dynamic> one(CloudFilter f) => {
          'fieldFilter': {
            'field': {'fieldPath': f.field},
            'op': f.op,
            'value': encodeValue(f.value),
          }
        };
    if (filters.length == 1) return one(filters.first);
    return {
      'compositeFilter': {'op': 'AND', 'filters': filters.map(one).toList()}
    };
  }

  Future<List<Map<String, dynamic>>> query(
    String collection, {
    List<CloudFilter> filters = const [],
    String? orderBy,
    bool descending = true,
    int limit = 300,
  }) async {
    final w = _where(filters);
    final rows = await _send('POST', ':runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': collection}
        ],
        if (w != null) 'where': w,
        if (orderBy != null)
          'orderBy': [
            {
              'field': {'fieldPath': orderBy},
              'direction': descending ? 'DESCENDING' : 'ASCENDING',
            }
          ],
        'limit': limit,
      },
    }) as List;
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final doc = (r as Map)['document'];
      if (doc is Map) out.add(decodeDoc(doc));
    }
    return out;
  }

  Future<int> count(String collection,
      {List<CloudFilter> filters = const []}) async {
    final w = _where(filters);
    final r = await _send('POST', ':runAggregationQuery', {
      'structuredAggregationQuery': {
        'structuredQuery': {
          'from': [
            {'collectionId': collection}
          ],
          if (w != null) 'where': w,
        },
        'aggregations': [
          {'alias': 'c', 'count': <String, dynamic>{}}
        ],
      },
    }) as List;
    final fields = ((r.first as Map)['result'] as Map)['aggregateFields'] as Map;
    return int.tryParse('${(fields['c'] as Map)['integerValue']}') ?? 0;
  }
}
