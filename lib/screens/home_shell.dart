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
import 'AI_upload.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = ShellTab.dashboard});

  final ShellTab initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
  }

  void _setIndex(int value) {
    if (_index == value) return;
    _history.add(_index);
    setState(() => _index = value);
  }

  Future<bool> _handleWillPop() async {
    if (_history.isNotEmpty) {
      final last = _history.removeLast();
      setState(() => _index = last);
      return false;
    }

    if (_index != ShellTab.dashboard.index) {
      setState(() => _index = ShellTab.dashboard.index);
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: ShellNav(
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
            AiUploadScreen(),
          ],
        ),
      ),
    );
  }
}
