import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const ids = Uuid();

class SecureSession extends LocalStorage {
  final storage = const FlutterSecureStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;
  @override
  Future<String?> accessToken() => storage.read(key: 'dolbom-session');
  @override
  Future<void> persistSession(String value) =>
      storage.write(key: 'dolbom-session', value: value);
  @override
  Future<void> removePersistedSession() =>
      storage.delete(key: 'dolbom-session');
}

class Api {
  static const base = String.fromEnvironment('API_BASE_URL');
  Future<dynamic> get(String route) => send(route);
  Future<dynamic> command(String action, Map<String, dynamic> payload) =>
      send('/api/command', {'action': action, 'payload': payload});
  Future<dynamic> send(String route, [Map<String, dynamic>? body]) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
    final uri = Uri.parse('$base$route');
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 25));
    final result = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(result['detail'] ?? '서버 요청 실패');
    }
    return result;
  }
}

class VisitStore extends ChangeNotifier {
  final Api api = Api();
  Database? db;
  Map<String, dynamic> bootstrap = {};
  List<Map<String, dynamic>> visits = [];
  String? error;
  String locationState = '기록 중단';
  bool syncing = false;
  StreamSubscription<Position>? gps;
  Timer? timer;
  bool consentLocation = false;
  bool _closed = false;
  Future<void> open(String uid) async {
    db = await openDatabase(
      path.join(await getDatabasesPath(), 'dolbom_$uid.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE visits (id TEXT PRIMARY KEY, body TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1)',
        );
        await d.execute(
          'CREATE TABLE events (id TEXT PRIMARY KEY, visit_id TEXT NOT NULL, seq INTEGER NOT NULL, body TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE locations (id TEXT PRIMARY KEY, visit_id TEXT NOT NULL, body TEXT NOT NULL, sent INTEGER NOT NULL DEFAULT 0)',
        );
        await d.execute(
          'CREATE TABLE outbox (id TEXT PRIMARY KEY, action TEXT NOT NULL, body TEXT NOT NULL)',
        );
      },
    );
    final cached = await db!.query(
      'cache',
      where: 'key=?',
      whereArgs: ['bootstrap'],
    );
    if (cached.isNotEmpty) {
      bootstrap = jsonDecode(cached.first['body'] as String);
    }
    final consent = await db!.query(
      'cache',
      where: 'key=?',
      whereArgs: ['location_consent'],
    );
    consentLocation = consent.isNotEmpty && consent.first['body'] == 'true';
    await reload();
    // Do not restart tracking on process restart without a visible user action.
    timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(sync()),
    );
    await refresh();
  }

  Future<void> reload() async {
    visits = (await db!.query('visits'))
        .map(
          (r) => {
            ...Map<String, dynamic>.from(jsonDecode(r['body'] as String)),
            'dirty': r['dirty'] == 1,
          },
        )
        .toList();
    if (!_closed) notifyListeners();
  }

  Future<void> refresh() async {
    try {
      bootstrap = Map<String, dynamic>.from(await api.get('/api/bootstrap'));
      await db!.insert('cache', {
        'key': 'bootstrap',
        'body': jsonEncode(bootstrap),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      error = null;
    } catch (e) {
      error = '서버에 연결하지 못했어요. 저장된 일정으로 이용할 수 있어요. ($e)';
    }
    await reload();
    await sync();
  }

  Map<String, dynamic>? get active {
    for (final v in visits) {
      if (v['state'] == 'active' || v['state'] == 'paused') return v;
    }
    return null;
  }

  Future<void> setLocationConsent(bool value) async {
    consentLocation = value;
    await db!.insert('cache', {
      'key': 'location_consent',
      'body': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!value) await stopTracking();
    notifyListeners();
  }

  Future<void> start(
    Map<String, dynamic> recipient, {
    Map<String, dynamic>? schedule,
    String reason = '',
  }) async {
    if (active != null) throw Exception('진행 중인 방문을 먼저 종료해주세요.');
    final id = ids.v4();
    final visit = {
      'id': id,
      'recipient_id': recipient['id'],
      'recipient_name': recipient['name'],
      'schedule_id': schedule?['id'],
      'temporary_reason': reason,
      'state': 'scheduled',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await db!.insert('visits', {
      'id': id,
      'body': jsonEncode(visit),
      'dirty': 1,
    });
    await event(id, 'start');
  }

  Future<List<Map<String, dynamic>>> events(String id) async =>
      (await db!.query(
            'events',
            where: 'visit_id=?',
            whereArgs: [id],
            orderBy: 'seq',
          ))
          .map(
            (r) => Map<String, dynamic>.from(jsonDecode(r['body'] as String)),
          )
          .toList();
  Future<void> event(String id, String kind) async {
    // Stop before awaiting storage/network. A failed write must not keep collecting.
    if (kind == 'pause' || kind == 'end') await stopTracking();
    await db!.transaction((tx) async {
      final rows = await tx.query('visits', where: 'id=?', whereArgs: [id]);
      final visit = Map<String, dynamic>.from(
        jsonDecode(rows.single['body'] as String),
      );
      const transitions = {
        'scheduled': {'start': 'active'},
        'active': {'pause': 'paused', 'end': 'ended'},
        'paused': {'resume': 'active', 'end': 'ended'},
      };
      final next = transitions[visit['state']]?[kind];
      if (next == null) throw Exception('현재 상태에서 할 수 없는 작업이에요.');
      final count = Sqflite.firstIntValue(
        await tx.rawQuery(
          'SELECT COALESCE(MAX(seq),0) FROM events WHERE visit_id=?',
          [id],
        ),
      )!;
      final e = {
        'id': ids.v4(),
        'seq': count + 1,
        'kind': kind,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      };
      await tx.insert('events', {
        'id': e['id'],
        'visit_id': id,
        'seq': e['seq'],
        'body': jsonEncode(e),
      });
      visit['state'] = next;
      await tx.update(
        'visits',
        {'body': jsonEncode(visit), 'dirty': 1},
        where: 'id=?',
        whereArgs: [id],
      );
    });
    await reload();
    if (kind == 'start' || kind == 'resume') await startTracking(id);
    unawaited(sync());
  }

  Future<void> startTracking(String id) async {
    await stopTracking();
    if (!consentLocation) {
      locationState = '위치 동의 없음 · 시간만 기록';
      notifyListeners();
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationState = '위치 권한 없음 · 시간만 기록';
        notifyListeners();
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationState = '위치 서비스 꺼짐 · 시간만 기록';
        notifyListeners();
        return;
      }
      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 60),
              maxUpdateAge: Duration.zero,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: '동행이음 방문 기록 중',
                notificationText: '휴게·종료하면 위치 기록을 중단합니다.',
                enableWakeLock: false,
              ),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              pauseLocationUpdatesAutomatically: true,
              showBackgroundLocationIndicator: true,
              allowBackgroundLocationUpdates: true,
            );
      gps = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) async {
          try {
            if (_closed || active?['id'] != id || active?['state'] != 'active') {
              return;
            }
            final sample = {
              'id': ids.v4(),
              'observed_at': p.timestamp.toUtc().toIso8601String(),
              'lat': p.latitude,
              'lon': p.longitude,
              'accuracy': p.accuracy,
            };
            await db!.insert('locations', {
              'id': sample['id'],
              'visit_id': id,
              'body': jsonEncode(sample),
              'sent': 0,
            });
            locationState =
                '최근 위치 기록 ${p.timestamp.toLocal().hour}:${p.timestamp.toLocal().minute.toString().padLeft(2, '0')}';
            if (!_closed) notifyListeners();
          } catch (e) {
            error = '위치 저장 실패 · 시간 기록을 확인해주세요.';
            if (!_closed) notifyListeners();
          }
        },
        onError: (Object e) {
          locationState = '위치 미확보 · 시간 기록 유지';
          if (!_closed) notifyListeners();
        },
      );
      locationState = '위치 기록 요청 중 · 수신 대기';
    } catch (e) {
      locationState = '위치 기록 불가 · 시간만 기록';
    }
    notifyListeners();
  }

  Future<void> stopTracking() async {
    await gps?.cancel();
    gps = null;
    locationState = '위치 기록 중단';
  }

  Future<void> queue(String action, Map<String, dynamic> body) async {
    await db!.insert('outbox', {
      'id': ids.v4(),
      'action': action,
      'body': jsonEncode(body),
    });
    notifyListeners();
    unawaited(sync());
  }

  Future<int> pending() async =>
      ((await db!.query('visits', where: 'dirty=1')).length +
      (await db!.query('outbox')).length +
      (await db!.query('locations', where: 'sent=0')).length);
  Future<void> sync() async {
    if (syncing || db == null || _closed) return;
    syncing = true;
    try {
      for (final row in await db!.query('visits')) {
        final v = Map<String, dynamic>.from(jsonDecode(row['body'] as String));
        final points = await db!.query(
          'locations',
          where: 'visit_id=? AND sent=0',
          whereArgs: [v['id']],
          limit: 500,
        );
        if (row['dirty'] == 0 && points.isEmpty) continue;
        final sentEvents = await events(v['id']);
        await api.command('sync', {
          ...v,
          'events': sentEvents,
          'locations': points
              .map((p) => jsonDecode(p['body'] as String))
              .toList(),
        });
        // Conditional clear: an event written while HTTP was in flight stays dirty.
        await db!.transaction((tx) async {
          final latest = Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(seq),0) FROM events WHERE visit_id=?',
              [v['id']],
            ),
          );
          if (latest == sentEvents.length) {
            await tx.rawUpdate(
              'UPDATE visits SET dirty=0 WHERE id=? AND body=?',
              [v['id'], row['body']],
            );
          }
          for (final p in points) {
            await tx.update(
              'locations',
              {'sent': 1},
              where: 'id=?',
              whereArgs: [p['id']],
            );
          }
        });
      }
      for (final q in await db!.query('outbox')) {
        await api.command(
          q['action'] as String,
          Map<String, dynamic>.from(jsonDecode(q['body'] as String)),
        );
        await db!.delete('outbox', where: 'id=?', whereArgs: [q['id']]);
      }
      error = null;
    } catch (e) {
      error = '전송 대기 · 휴대폰 기록은 보관 중입니다. $e';
    } finally {
      syncing = false;
      if (!_closed) await reload();
    }
  }

  @override
  void dispose() {
    _closed = true;
    timer?.cancel();
    unawaited(stopTracking());
    super.dispose();
  }
}

Map<String, int> durations(List<Map<String, dynamic>> events, {DateTime? now}) {
  int care = 0, pause = 0;
  DateTime? previous;
  String? kind;
  for (final e in events) {
    final t = DateTime.parse(e['occurred_at']);
    if (previous != null) {
      final seconds = t.difference(previous).inSeconds;
      if (kind == 'start' || kind == 'resume') care += seconds;
      if (kind == 'pause') pause += seconds;
    }
    previous = t;
    kind = e['kind'];
  }
  if (previous != null && kind != 'end') {
    final seconds = (now ?? DateTime.now()).difference(previous).inSeconds;
    if (kind == 'pause') {
      pause += seconds;
    } else {
      care += seconds;
    }
  }
  return {'care': care, 'pause': pause, 'total': care + pause};
}
