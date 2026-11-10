import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/plan.dart';

class _Edit {
  _Edit(Plan p)
      : id = p.id,
        en = TextEditingController(text: p.nameEn),
        si = TextEditingController(text: p.nameSi),
        days = TextEditingController(text: '${p.days}'),
        price = TextEditingController(text: '${p.price}'),
        enabled = p.enabled;

  final String id;
  final TextEditingController en, si, days, price;
  bool enabled;

  void dispose() {
    en.dispose();
    si.dispose();
    days.dispose();
    price.dispose();
  }

  Plan toPlan() => Plan(
        id: id,
        nameEn: en.text.trim().isEmpty ? id : en.text.trim(),
        nameSi: si.text.trim().isEmpty ? en.text.trim() : si.text.trim(),
        days: int.tryParse(days.text.trim()) ?? 1,
        price: int.tryParse(price.text.trim()) ?? 0,
        enabled: enabled,
      );
}

/// Edit plans, prices, payment text and WhatsApp number.
/// The game reads this on the plans screen.
class PricesPage extends StatefulWidget {
  const PricesPage({super.key});

  @override
  State<PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends State<PricesPage> {
  final List<_Edit> _edits = [];
  final _pay = TextEditingController();
  final _wa = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final e in _edits) {
      e.dispose();
    }
    _pay.dispose();
    _wa.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await repo.loadConfig();
      for (final e in _edits) {
        e.dispose();
      }
      _edits
        ..clear()
        ..addAll(cfg.plans.map(_Edit.new));
      _pay.text = cfg.payInfo;
      _wa.text = cfg.whatsapp;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final plans = _edits.map((e) => e.toPlan()).toList();
    if (plans.any((p) => p.days < 1 || p.price < 1)) {
      toast(context, 'Days and price must be 1 or more');
      return;
    }
    setState(() => _saving = true);
    try {
      await repo.saveConfig(PlanConfig(
        plans: plans,
        payInfo: _pay.text.trim(),
        whatsapp: _wa.text.replaceAll(RegExp(r'[^0-9]'), ''),
      ));
      if (mounted) toast(context, 'Saved. The game shows the new prices.');
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _add() {
    setState(() {
      _edits.add(_Edit(Plan(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        nameEn: 'New plan',
        nameSi: 'අලුත් plan',
        days: 7,
        price: 50,
      )));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
      children: [
        if (_error != null) Text('Could not load: $_error'),
        const Text(
          'Prices are shown in the game. Changing a price does not change plans people already bought.',
          style: TextStyle(fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _edits.length; i++) _planCard(i),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add plan'),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _pay,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'How to pay (shown in the game)',
            hintText: 'Bank / eZ Cash number, name ...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _wa,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp number (94771234567)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
    );
  }

  Widget _planCard(int i) {
    final e = _edits[i];
    return Card(
      key: ValueKey(e.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: e.en,
                    decoration: const InputDecoration(labelText: 'Name (English)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: e.si,
                    decoration: const InputDecoration(labelText: 'නම (සිංහල)'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: e.days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Days'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: e.price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (Rs.)'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Show in game'),
                Switch(
                  value: e.enabled,
                  onChanged: (v) => setState(() => e.enabled = v),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete plan',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _edits.removeAt(i);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
