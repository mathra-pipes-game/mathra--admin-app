import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/repo.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Stats? _s;
  String? _error;
  bool _loading = true;

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
      final s = await repo.stats();
      if (mounted) setState(() => _s = s);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _pct(int a, int b) => b == 0 ? '0%' : '${(a * 100 / b).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading && s == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Could not load: $_error'),
              ),
            ),
          if (s != null) ...[
            _revenue(s),
            const SizedBox(height: 14),
            _grid(s),
            const SizedBox(height: 14),
            _funnel(s),
            const SizedBox(height: 10),
            const Text(
              'Installs = phones that opened the game at least once (real data from the game, not the Play Store count). Pull down to refresh.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _revenue(Stats s) {
    final cs = Theme.of(context).colorScheme;
    Widget cell(String label, int v) => Expanded(
          child: Column(
            children: [
              Text('Rs. $v',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer)),
              Text(label, style: TextStyle(color: cs.onPrimaryContainer)),
            ],
          ),
        );
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            cell('Today', s.revenueToday),
            cell('This month', s.revenueMonth),
            cell('Total', s.revenueTotal),
          ],
        ),
      ),
    );
  }

  Widget _grid(Stats s) {
    final items = <(IconData, String, int)>[
      (Icons.download_rounded, 'Installs (downloads)', s.installs),
      (Icons.visibility_rounded, 'Viewed plans', s.planViewers),
      (Icons.shopping_cart_rounded, 'Took a plan (orders)', s.ordersTotal),
      (Icons.payments_rounded, 'Paid customers', s.payingCustomers),
      (Icons.hourglass_top_rounded, 'Waiting payment', s.pending),
      (Icons.verified_rounded, 'Paid orders', s.paidOrders),
      (Icons.workspace_premium_rounded, 'Active subscribers', s.activeSubs),
      (Icons.timer_off_rounded, 'Expired / removed', s.expiredSubs),
      (Icons.bolt_rounded, 'Active last 24h', s.active24h),
      (Icons.calendar_view_week_rounded, 'Active last 7 days', s.active7d),
      (Icons.emoji_events_rounded, 'Leaderboard players', s.players),
      (Icons.cancel_rounded, 'Rejected orders', s.rejected),
    ];
    final w = (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          SizedBox(
            width: w,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(it.$1, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('${it.$3}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(it.$2, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _funnel(Stats s) {
    Widget row(String label, int v, int base) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(label)),
              Expanded(
                child: LinearProgressIndicator(
                  value: base == 0 ? 0 : (v / base).clamp(0.0, 1.0),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              SizedBox(
                width: 92,
                child: Text('$v  (${_pct(v, base)})', textAlign: TextAlign.end),
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Funnel', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            row('Installed', s.installs, s.installs),
            row('Viewed plans', s.planViewers, s.installs),
            row('Ordered', s.ordersTotal, s.installs),
            row('Paid', s.payingCustomers, s.installs),
          ],
        ),
      ),
    );
  }
}
