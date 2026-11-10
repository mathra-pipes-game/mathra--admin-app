import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/plan.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _status = 'pending';
  List<Map<String, dynamic>> _items = [];
  PlanConfig _cfg = PlanConfig.defaults();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _cfg = await repo.loadConfig();
      final list = await repo.orders(_status);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// The plan the order was for - prices come from YOUR plan list, never
  /// from the phone.
  Plan _planFor(Map<String, dynamic> o) {
    for (final p in _cfg.plans) {
      if (p.id == '${o['planId']}') return p;
    }
    return Plan(
      id: '${o['planId']}',
      nameEn: '${o['planName']}',
      nameSi: '${o['planName']}',
      days: (o['days'] is int) ? o['days'] as int : 1,
      price: (o['price'] is int) ? o['price'] as int : 0,
    );
  }

  Future<void> _confirm(Map<String, dynamic> o) async {
    final plan = _planFor(o);
    final asked = (o['price'] is int) ? o['price'] as int : 0;
    final mismatch = asked != plan.price;
    final ok = await confirmDialog(
      context,
      'Confirm payment?',
      'Phone ${o['deviceId']}\n'
      'Player: ${o['playerName']}\n'
      'Plan: ${plan.nameEn} (${plan.days} days)\n'
      'Amount to receive: Rs. ${plan.price}'
      '${mismatch ? '\n\n⚠ The phone said Rs. $asked, your price list says Rs. ${plan.price}.' : ''}'
      '\n\nOnly press Confirm after the money really arrived.',
      ok: 'Money received',
    );
    if (!ok || !mounted) return;
    try {
      final exp = await repo.confirmOrder(o, plan);
      if (mounted) toast(context, 'Activated until ${fmtDate(exp)}');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> o) async {
    final ok = await confirmDialog(context, 'Reject order?',
        'Order ${o['_id']} will be marked as rejected.', ok: 'Reject');
    if (!ok || !mounted) return;
    try {
      await repo.rejectOrder('${o['_id']}');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> o) async {
    final ok = await confirmDialog(context, 'Delete record?',
        'Order ${o['_id']} will be deleted for good.', ok: 'Delete');
    if (!ok || !mounted) return;
    try {
      await repo.deleteOrder('${o['_id']}');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'paid', label: Text('Paid')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_status},
            onSelectionChanged: (v) {
              setState(() => _status = v.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
              children: [
                if (_loading && _items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null) Text('Could not load: $_error'),
                if (!_loading && _items.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('No orders here')),
                  ),
                for (final o in _items) _tile(o),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> o) {
    final price = (o['price'] is int) ? o['price'] as int : 0;
    final created = (o['createdAt'] is int) ? o['createdAt'] as int : 0;
    final paidAt = (o['paidAt'] is int) ? o['paidAt'] as int : 0;
    final exp = (o['expiresAt'] is int) ? o['expiresAt'] as int : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${o['planName']}  –  Rs. $price',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Text('${o['_id']}',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${o['playerName']}  •  ${o['deviceId']}'),
            Text('Ordered: ${fmtDate(created)}'),
            if (_status == 'paid') Text('Paid: ${fmtDate(paidAt)}  •  until ${fmtDate(exp)}'),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                children: [
                  if (_status == 'pending') ...[
                    OutlinedButton(onPressed: () => _reject(o), child: const Text('Reject')),
                    FilledButton.icon(
                      onPressed: () => _confirm(o),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm paid'),
                    ),
                  ],
                  if (_status == 'rejected')
                    OutlinedButton(onPressed: () => _delete(o), child: const Text('Delete')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
