import 'dart:math';

import 'package:mathra_admin/auth.dart';
import 'package:mathra_admin/cloud_client.dart';
import 'package:mathra_admin/plan.dart';

class Stats {
  int installs = 0; // devices that opened the game (= downloads/installs)
  int active24h = 0;
  int active7d = 0;
  int planViewers = 0; // devices that opened the plans screen
  int ordersTotal = 0; // players who picked a plan
  int pending = 0;
  int paidOrders = 0;
  int payingCustomers = 0; // distinct phones that paid
  int rejected = 0;
  int activeSubs = 0;
  int expiredSubs = 0;
  int players = 0; // leaderboard players
  int revenueToday = 0;
  int revenueMonth = 0;
  int revenueTotal = 0;
}

class AdminRepo {
  AdminRepo(this.auth);
  final AdminAuth auth;
  final CloudClient _client = CloudClient();

  static const int dayMs = 86400000;

  int now() => CloudClient.serverNow().millisecondsSinceEpoch;

  Future<CloudClient> _c() async {
    _client.idToken = await auth.token();
    return _client;
  }

  // ───────────── stats ─────────────

  Future<Stats> stats() async {
    final c = await _c();
    final t = now();
    final s = Stats();

    Future<int> cnt(String col, [List<CloudFilter> f = const []]) =>
        c.count(col, filters: f);

    final r = await Future.wait<int>([
      cnt('devices'), // 0
      cnt('devices', [CloudFilter('lastSeen', 'GREATER_THAN_OR_EQUAL', t - dayMs)]),
      cnt('devices', [CloudFilter('lastSeen', 'GREATER_THAN_OR_EQUAL', t - 7 * dayMs)]),
      cnt('devices', [const CloudFilter('planViews', 'GREATER_THAN', 0)]),
      cnt('orders'), // 4
      cnt('orders', [const CloudFilter('status', 'EQUAL', 'pending')]),
      cnt('orders', [const CloudFilter('status', 'EQUAL', 'rejected')]),
      cnt('subs', [CloudFilter('expiresAt', 'GREATER_THAN', t)]), // 7
      cnt('subs'),
      cnt('players'),
    ]);
    s.installs = r[0];
    s.active24h = r[1];
    s.active7d = r[2];
    s.planViewers = r[3];
    s.ordersTotal = r[4];
    s.pending = r[5];
    s.rejected = r[6];
    s.activeSubs = r[7];
    s.expiredSubs = max(0, r[8] - r[7]);
    s.players = r[9];

    final paid = await c.query('orders',
        filters: const [CloudFilter('status', 'EQUAL', 'paid')], limit: 1000);
    s.paidOrders = paid.length;
    final dev = <String>{};
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final startToday = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final startMonth = DateTime(d.year, d.month, 1).millisecondsSinceEpoch;
    for (final o in paid) {
      final price = (o['price'] is int) ? o['price'] as int : 0;
      final at = (o['paidAt'] is int) ? o['paidAt'] as int : 0;
      if (price > 0) dev.add('${o['deviceId']}');
      s.revenueTotal += price;
      if (at >= startMonth) s.revenueMonth += price;
      if (at >= startToday) s.revenueToday += price;
    }
    s.payingCustomers = dev.length;
    return s;
  }

  // ───────────── orders ─────────────

  Future<List<Map<String, dynamic>>> orders(String status) async {
    final c = await _c();
    final list = await c.query('orders',
        filters: [CloudFilter('status', 'EQUAL', status)], limit: 300);
    int at(Map<String, dynamic> m) =>
        (m[status == 'paid' ? 'paidAt' : 'createdAt'] is int)
            ? m[status == 'paid' ? 'paidAt' : 'createdAt'] as int
            : 0;
    list.sort((a, b) => at(b).compareTo(at(a)));
    return list;
  }

  /// Money received -> switch the plan on (stacks on top of a running plan).
  Future<int> confirmOrder(Map<String, dynamic> order, Plan plan) async {
    final c = await _c();
    final code = '${order['_id']}';
    final deviceId = '${order['deviceId']}';
    final sub = await _subWrites(c, deviceId, plan, code);
    final t = now();
    await c.commit([
      sub.write,
      CloudClient.writeUpdate('orders/$code', {
        'status': 'paid',
        'paidAt': t,
        'expiresAt': sub.expiresAt,
        'price': plan.price,
        'planId': plan.id,
        'days': plan.days,
      }),
    ]);
    return sub.expiresAt;
  }

  Future<void> rejectOrder(String code) async {
    final c = await _c();
    await c.patchDoc('orders/$code', {'status': 'rejected', 'paidAt': now()});
  }

  Future<void> deleteOrder(String code) async {
    final c = await _c();
    await c.deleteDoc('orders/$code');
  }

  // ───────────── subscriptions ─────────────

  Future<({Map<String, dynamic> write, int expiresAt})> _subWrites(
    CloudClient c,
    String deviceId,
    Plan plan,
    String orderCode,
  ) async {
    final existing = await c.getDoc('subs/$deviceId');
    final t = now();
    final revoked = existing?['revoked'] == true;
    final curExp = (!revoked && existing?['expiresAt'] is int)
        ? existing!['expiresAt'] as int
        : 0;
    final running = curExp > t;
    final newExp = (running ? curExp : t) + plan.days * dayMs;
    final write = CloudClient.writeUpdate('subs/$deviceId', {
      'deviceId': deviceId,
      'planId': plan.id,
      'planName': plan.nameEn,
      'expiresAt': newExp,
      'revoked': false,
      'startedAt': (running && existing?['startedAt'] is int)
          ? existing!['startedAt'] as int
          : t,
      'updatedAt': t,
      'lastOrder': orderCode,
    });
    return (write: write, expiresAt: newExp);
  }

  Future<List<Map<String, dynamic>>> subs() async {
    final c = await _c();
    final list = await c.query('subs', limit: 500);
    int exp(Map<String, dynamic> m) =>
        (m['expiresAt'] is int) ? m['expiresAt'] as int : 0;
    list.sort((a, b) => exp(b).compareTo(exp(a)));
    return list;
  }

  /// Takes the plan away immediately (game notices within minutes).
  Future<void> revoke(String deviceId) async {
    final c = await _c();
    final t = now();
    await c.patchDoc('subs/$deviceId', {
      'revoked': true,
      'expiresAt': 0,
      'revokedAt': t,
      'updatedAt': t,
    });
  }

  /// Manual plan for a Device ID (counts as a paid order unless [paid] false).
  Future<int> grant(String deviceId, Plan plan, {bool paid = true}) async {
    final c = await _c();
    final id = normDeviceId(deviceId);
    final code = 'M${_rand(7)}';
    final sub = await _subWrites(c, id, plan, code);
    final t = now();
    await c.commit([
      sub.write,
      CloudClient.writeUpdate('orders/$code', {
        'deviceId': id,
        'playerName': 'manual',
        'planId': plan.id,
        'planName': plan.nameEn,
        'days': plan.days,
        'price': paid ? plan.price : 0,
        'status': 'paid',
        'createdAt': t,
        'paidAt': t,
        'expiresAt': sub.expiresAt,
      }),
    ]);
    return sub.expiresAt;
  }

  /// "a1b2c3d4e5" / "A1B2C 3D4E5" -> "A1B2C-3D4E5" (the game's format).
  static String normDeviceId(String s) {
    final c = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return c.length == 10 ? '${c.substring(0, 5)}-${c.substring(5)}' : c;
  }

  static String _rand(int n) {
    const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => a[r.nextInt(a.length)]).join();
  }

  // ───────────── plans / prices ─────────────

  Future<PlanConfig> loadConfig() async {
    final c = await _c();
    final d = await c.getDoc('config/plans');
    return d == null ? PlanConfig.defaults() : PlanConfig.fromDoc(d);
  }

  Future<void> saveConfig(PlanConfig cfg) async {
    final c = await _c();
    await c.patchDoc('config/plans', cfg.toDoc());
  }
}
