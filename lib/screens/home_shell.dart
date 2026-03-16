import 'package:flutter/material.dart';

import '../widgets/shell_nav.dart';
import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'Analytics.dart';
import 'vendors.dart';
import 'customer.dart';
import 'delivery.dart';
import 'store_settings.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = ShellTab.dashboard});

  final ShellTab initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
  }

  void _setIndex(int value) {
    if (_index == value) return;
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    return ShellNav(
      index: _index,
      setIndex: _setIndex,
      child: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          OrdersScreen(),
          ProductsScreen(),
          PosBillingScreen(),
          AnalyticsScreen(),
          VendorsScreen(),
          CustomerScreen(),
          DeliveryScreen(),
          StoreSettingsScreen(),
        ],
      ),
    );
  }
}
