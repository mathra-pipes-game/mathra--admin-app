import 'package:flutter/material.dart';
import 'package:mathra_admin/auth.dart';
import 'package:mathra_admin/plan.dart';
import 'package:mathra_admin/repo.dart';

final AdminAuth auth = AdminAuth();
final AdminRepo repo = AdminRepo(auth);

String fmtDate(int ms) {
  if (ms <= 0) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String leftText(int expiresMs) {
  final left = expiresMs - repo.now();
  if (left <= 0) return 'expired';
  final d = Duration(milliseconds: left);
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m left';
  return '${d.inMinutes}m left';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String body, {
  String ok = 'Yes',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

Future<Plan?> pickPlan(BuildContext context, List<Plan> plans, {String title = 'Choose plan'}) {
  return showDialog<Plan>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final p in plans)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Text('${p.nameEn}  •  ${p.days} d  •  Rs. ${p.price}'),
          ),
      ],
    ),
  );
}
