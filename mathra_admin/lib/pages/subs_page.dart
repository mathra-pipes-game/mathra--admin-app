import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/plan.dart';
import 'package:mathra_admin/repo.dart';

class SubsPage extends StatefulWidget {
  const SubsPage({super.key});

  @override
  State<SubsPage> createState() => _SubsPageState();
}

class _SubsPageState extends State<SubsPage> {
  bool _active = true;
  List<Map<String, dynamic>> _all = [];
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
      final list = await repo.subs();
      if (mounted) setState(() => _all = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  int _exp(Map<String, dynamic> m) =>
      (m['expiresAt'] is int) ? m['expiresAt'] as int : 0;

  Future<void> _remove(Map<String, dynamic> m) async {
    final ok = await confirmDialog(
      context,
      'Remove plan?',
      '${m['_id']} will lose unlimited hints right away '
      '(the game notices within a few minutes).',
      ok: 'Remove',
    );
    if (!ok || !mounted) return;
    try {
      await repo.revoke('${m['_id']}');
      if (mounted) toast(context, 'Removed');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _extend(Map<String, dynamic> m) async {
    final plan = await pickPlan(
      context,
      _cfg.plans.where((p) => p.enabled).toList(),
      title: 'Add time to ${m['_id']}',
    );
    if (plan == null || !mounted) return;
    try {
      final exp = await repo.grant('${m['_id']}', plan);
      if (mounted) toast(context, 'Now until ${fmtDate(exp)}');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _grantDialog() async {
    final id = TextEditingController();
    Plan? plan;
    var paid = true;
    final plans = _cfg.plans.where((p) => p.enabled).toList();
    if (plans.isNotEmpty) plan = plans.first;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Give a plan manually'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: id,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Device ID (A1B2C-3D4E5)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<Plan>(
                  isExpanded: true,
                  value: plan,
                  items: [
                    for (final p in plans)
                      DropdownMenuItem(
                        value: p,
                        child: Text('${p.nameEn} – Rs. ${p.price}'),
                      ),
                  ],
                  onChanged: (v) => setS(() => plan = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Counts as paid'),
                  subtitle: const Text('Off = free gift (no revenue)'),
                  value: paid,
                  onChanged: (v) => setS(() => paid = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Give')),
          ],
        ),
      ),
    );
    final devId = AdminRepo.normDeviceId(id.text);
    id.dispose();
    if (go != true || plan == null || !mounted) return;
    if (devId.length < 8) {
      toast(context, 'Enter the Device ID');
      return;
    }
    try {
      final exp = await repo.grant(devId, plan!, paid: paid);
      if (mounted) toast(context, 'Active until ${fmtDate(exp)}');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = repo.now();
    final list = _all.where((m) => (_exp(m) > t) == _active).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _grantDialog,
        icon: const Icon(Icons.add),
        label: const Text('Give plan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text('Active (${_all.where((m) => _exp(m) > t).length})'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Expired / removed (${_all.where((m) => _exp(m) <= t).length})'),
                ),
              ],
              selected: {_active},
              onSelectionChanged: (v) => setState(() => _active = v.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                children: [
                  if (_loading && _all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null) Text('Could not load: $_error'),
                  if (!_loading && list.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('Nobody here')),
                    ),
                  for (final m in list)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${m['_id']}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          m['revoked'] == true
                              ? '${m['planName']} • removed ${fmtDate((m['revokedAt'] is int) ? m['revokedAt'] as int : 0)}'
                              : '${m['planName']} • ends ${fmtDate(_exp(m))}\n${leftText(_exp(m))}',
                        ),
                        isThreeLine: m['revoked'] != true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'remove' ? _remove(m) : _extend(m),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'extend', child: Text('Add time')),
                            if (_active)
                              const PopupMenuItem(value: 'remove', child: Text('Remove plan')),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
