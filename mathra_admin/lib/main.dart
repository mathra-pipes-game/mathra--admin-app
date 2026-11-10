import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/pages/home_page.dart';
import 'package:mathra_admin/pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mathra Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3949AB)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3949AB),
          brightness: Brightness.dark,
        ),
      ),
      home: const _Gate(),
    );
  }
}

/// Login screen unless a saved login still works.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _in;

  @override
  void initState() {
    super.initState();
    auth.restore().then((ok) {
      if (mounted) setState(() => _in = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_in == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _in!
        ? HomePage(onSignOut: () => setState(() => _in = false))
        : LoginPage(onDone: () => setState(() => _in = true));
  }
}
