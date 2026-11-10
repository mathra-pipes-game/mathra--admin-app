import 'package:flutter/material.dart';
import 'package:mathra_admin/app_state.dart';
import 'package:mathra_admin/pages/dashboard_page.dart';
import 'package:mathra_admin/pages/orders_page.dart';
import 'package:mathra_admin/pages/prices_page.dart';
import 'package:mathra_admin/pages/subs_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  static const _titles = ['Dashboard', 'Orders', 'Subscribers', 'Prices'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const OrdersPage(),
      const SubsPage(),
      const PricesPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Logout?', 'Sign out of the admin app.');
              if (!ok) return;
              await auth.signOut();
              widget.onSignOut();
            },
          ),
        ],
      ),
      // Pages rebuild (and reload) every time you switch tab.
      body: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Subscribers'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Prices'),
        ],
      ),
    );
  }
}
