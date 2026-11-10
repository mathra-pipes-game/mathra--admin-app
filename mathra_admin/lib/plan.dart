import 'dart:convert';

/// One paid plan (unlimited hints for [days] days).
class Plan {
  const Plan({
    required this.id,
    required this.nameEn,
    required this.nameSi,
    required this.days,
    required this.price,
    this.enabled = true,
  });

  final String id;
  final String nameEn;
  final String nameSi;
  final int days;
  final int price; // Rs
  final bool enabled;

  Plan copyWith({String? nameEn, String? nameSi, int? days, int? price, bool? enabled}) =>
      Plan(
        id: id,
        nameEn: nameEn ?? this.nameEn,
        nameSi: nameSi ?? this.nameSi,
        days: days ?? this.days,
        price: price ?? this.price,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': nameEn,
        'si': nameSi,
        'days': days,
        'price': price,
        'on': enabled,
      };

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: '${j['id']}',
        nameEn: '${j['en'] ?? ''}',
        nameSi: '${j['si'] ?? ''}',
        days: (j['days'] as num?)?.toInt() ?? 1,
        price: (j['price'] as num?)?.toInt() ?? 0,
        enabled: j['on'] != false,
      );
}

/// Plans + payment text. Stored in Firestore `config/plans`
/// (the admin app edits it). These defaults are used until then.
class PlanConfig {
  const PlanConfig({
    required this.plans,
    required this.payInfo,
    required this.whatsapp,
  });

  final List<Plan> plans;
  final String payInfo;

  /// International format, digits only (e.g. 94783756055).
  final String whatsapp;

  static const List<Plan> defaultPlans = [
    Plan(id: 'd1', nameEn: '1 Day', nameSi: 'දවස් 1', days: 1, price: 5),
    Plan(id: 'd2', nameEn: '2 Days', nameSi: 'දවස් 2', days: 2, price: 10),
    Plan(id: 'm1', nameEn: '1 Month', nameSi: 'මාස 1', days: 30, price: 100),
    Plan(id: 'm2', nameEn: '2 Months', nameSi: 'මාස 2', days: 60, price: 200),
    Plan(id: 'm6', nameEn: '6 Months', nameSi: 'මාස 6', days: 180, price: 500),
    Plan(id: 'y1', nameEn: '1 Year', nameSi: 'අවුරුද්ද 1', days: 365, price: 1000),
  ];

  factory PlanConfig.defaults() => const PlanConfig(
        plans: defaultPlans,
        payInfo: 'Pay by bank transfer / eZ Cash, then send the slip on WhatsApp.',
        whatsapp: '94783756055',
      );

  Map<String, Object?> toDoc() => {
        'plans': jsonEncode(plans.map((p) => p.toJson()).toList()),
        'payInfo': payInfo,
        'whatsapp': whatsapp,
      };

  factory PlanConfig.fromDoc(Map<String, dynamic> d) {
    final def = PlanConfig.defaults();
    var plans = def.plans;
    try {
      final raw = d['plans'];
      if (raw is String && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => Plan.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((p) => p.id.isNotEmpty && p.days > 0)
            .toList();
        if (list.isNotEmpty) plans = list;
      }
    } catch (_) {}
    final pay = '${d['payInfo'] ?? ''}'.trim();
    final wa = '${d['whatsapp'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    return PlanConfig(
      plans: plans,
      payInfo: pay.isEmpty ? def.payInfo : pay,
      whatsapp: wa.isEmpty ? def.whatsapp : wa,
    );
  }
}
