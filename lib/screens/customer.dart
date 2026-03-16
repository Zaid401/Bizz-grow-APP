import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'slider.dart';
import 'Analytics.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'notifications.dart';
import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

class CustomerRecord {
  const CustomerRecord({
    required this.name,
    required this.phone,
    required this.tier,
    required this.orders,
    required this.totalSpent,
    required this.joinedAt,
  });

  final String name;
  final String phone;
  final String tier; // All | VIP | Regular | New
  final int orders;
  final double totalSpent;
  final DateTime joinedAt;
}

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final TextEditingController _search = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  StoreInfo? _storeInfo;
  bool _loading = true;
  String _filter = 'All';
  int _unreadNotifications = 0;

  final List<CustomerRecord> _all = [
    CustomerRecord(
      name: 'Laskshay',
      phone: '9352443837',
      tier: 'New',
      orders: 1,
      totalSpent: 10,
      joinedAt: DateTime(2026, 2, 3),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() => _storeInfo = dash.storeInfo);
      await _loadUnreadNotifications();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final user = _client.auth.currentUser;
      final userId = user?.id;
      final storeId = user?.userMetadata?['store_id']?.toString();

      List<Map<String, dynamic>> rows = const [];

      if (storeId != null && storeId.trim().isNotEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.or('store_id.eq.$storeId,user_id.eq.$userId');
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.eq('store_id', storeId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (rows.isEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.eq('user_id', userId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (!mounted) return;
      setState(() => _unreadNotifications = rows.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  List<CustomerRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((c) {
      final matchesQuery = q.isEmpty
          ? true
          : c.name.toLowerCase().contains(q) || c.phone.contains(q);
      final matchesTier = _filter == 'All' || c.tier == _filter;
      return matchesQuery && matchesTier;
    }).toList();
  }

  int get _totalCustomers => _all.length;
  int get _vipCustomers => _all.where((c) => c.tier == 'VIP').length;
  int get _newThisMonth {
    final now = DateTime.now();
    return _all
        .where((c) => c.tier == 'New' && c.joinedAt.month == now.month)
        .length;
  }

  String get _avgLifetimeValue {
    if (_all.isEmpty) return '₹0';
    final total = _all.fold<double>(0, (sum, c) => sum + c.totalSpent);
    final avg = total / _all.length;
    return '₹${avg.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4D0E7F);
    const soft = Color(0xFFF0EAF7);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: DashboardDrawer(
        onClose: () => Navigator.of(context).pop(),
        store: _storeInfo,
        onOpenDashboard: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.dashboard,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenPosBilling: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.posBilling,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenOrders: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.orders,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenProducts: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.products,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenAnalytics: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.analytics,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenVendors: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.vendors,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenDelivery: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.delivery,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenStoreSettings: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.storeSettings,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenCustomers: () => Navigator.of(context).pop(),
        activeCustomers: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF8B7F95),
        onTap: (index) {
          if (index == 0) {
            ShellNav.switchTo(context, ShellTab.dashboard);
          } else if (index == 1) {
            ShellNav.switchTo(context, ShellTab.orders);
          } else if (index == 2) {
            ShellNav.switchTo(context, ShellTab.products);
          } else if (index == 4) {
            showMoreActionsSheet(
              context: context,
              onOpenDashboard: () {
                ShellNav.switchTo(context, ShellTab.dashboard);
              },
              onOpenOrders: () {
                ShellNav.switchTo(context, ShellTab.orders);
              },
              onOpenProducts: () {
                ShellNav.switchTo(context, ShellTab.products);
              },
              onOpenPosBilling: () {
                ShellNav.switchTo(context, ShellTab.posBilling);
              },
              onOpenAnalytics: () {
                ShellNav.switchTo(context, ShellTab.analytics);
              },
              onOpenVendors: () {
                ShellNav.switchTo(context, ShellTab.vendors);
              },
              activeModule: MoreActionsModule.vendors,
              onOpenAiUpload: () {
                ShellNav.switchTo(context, ShellTab.products);
              },
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_outlined),
            label: 'Share',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              TopHeaderSliver(
                backgroundColor: Colors.white,
                accent: accent,
                unreadNotifications: _unreadNotifications,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      )
                      .then((_) => _loadUnreadNotifications());
                },
                logoUrl: _storeInfo?.logoUrl,
                initials: _initials(_storeInfo?.name ?? 'Store'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TitleBlock(accent: accent),
                    const SizedBox(height: 16),
                    _ActionsRow(accent: accent),
                    const SizedBox(height: 14),
                    _StatsGrid(
                      accent: accent,
                      total: _totalCustomers,
                      vip: _vipCustomers,
                      newThisMonth: _newThisMonth,
                      avgLifetime: _avgLifetimeValue,
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _FilterChips(
                      selected: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      _CustomerTable(
                        customers: _filtered,
                        accent: accent,
                        soft: soft,
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8DAF5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: Color(0xFF6B1FB1),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF241132),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your customer relationships',
                style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4A3A59),
            side: const BorderSide(color: Color(0xFFE3DFEA)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {},
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text(
            'Export',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {},
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text(
            'Add Customer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.accent,
    required this.total,
    required this.vip,
    required this.newThisMonth,
    required this.avgLifetime,
  });

  final Color accent;
  final int total;
  final int vip;
  final int newThisMonth;
  final String avgLifetime;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: 'Total Customers',
        value: '$total',
        icon: Icons.people_alt_outlined,
        tint: accent,
      ),
      _StatCard(
        label: 'VIP Customers',
        value: '$vip',
        icon: Icons.workspace_premium_outlined,
        tint: const Color(0xFF9C76D2),
      ),
      _StatCard(
        label: 'New This Month',
        value: '$newThisMonth',
        icon: Icons.person_add_alt_outlined,
        tint: const Color(0xFF2EC28B),
      ),
      _StatCard(
        label: 'Avg. Lifetime Value',
        value: avgLifetime,
        icon: Icons.trending_up_outlined,
        tint: const Color(0xFFE3AA44),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241132),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F758B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search customers...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF4A3A59)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3DFEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4D0E7F)),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const chipBg = Color(0xFFEDE6F4);
    const selectedBg = Color(0xFFDCD2EE);

    Widget chip(String label) {
      final isActive = selected == label;
      return GestureDetector(
        onTap: () => onChanged(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? selectedBg : chipBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A3A59),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All'),
          const SizedBox(width: 10),
          chip('VIP'),
          const SizedBox(width: 10),
          chip('Regular'),
          const SizedBox(width: 10),
          chip('New'),
        ],
      ),
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({
    required this.customers,
    required this.accent,
    required this.soft,
  });

  final List<CustomerRecord> customers;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3DFEA)),
        ),
        child: Column(
          children: const [
            Icon(Icons.inbox_outlined, size: 42, color: Color(0xFFB2A9BD)),
            SizedBox(height: 10),
            Text(
              'No customers found',
              style: TextStyle(
                color: Color(0xFF4A3A59),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try another filter or search term.',
              style: TextStyle(color: Color(0xFF7F758B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Customer',
                    style: TextStyle(
                      color: Color(0xFF4A3A59),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: Color(0xFF4A3A59),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Orders',
                    style: TextStyle(
                      color: Color(0xFF4A3A59),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total Spent',
                    style: TextStyle(
                      color: Color(0xFF4A3A59),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      color: Color(0xFF4A3A59),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...customers.map(
            (c) => Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE3DFEA))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE8DAF5),
                          child: Text(
                            _initials(c.name),
                            style: const TextStyle(
                              color: Color(0xFF6B1FB1),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF241132),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.phone,
                              style: const TextStyle(
                                color: Color(0xFF7F758B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _StatusPill(tier: c.tier)),
                  Expanded(
                    child: Text(
                      '${c.orders}',
                      style: const TextStyle(
                        color: Color(0xFF4A3A59),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '₹${c.totalSpent.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF241132),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            color: accent,
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.phone_outlined,
                            color: accent,
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF4A3A59),
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                      ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    IconData? icon;

    switch (tier) {
      case 'VIP':
        bg = const Color(0xFFFFF4E5);
        text = const Color(0xFF8B5E00);
        icon = Icons.workspace_premium_outlined;
        break;
      case 'Regular':
        bg = const Color(0xFFE6E2EE);
        text = const Color(0xFF4A3A59);
        break;
      case 'New':
        bg = const Color(0xFFE6F8EB);
        text = const Color(0xFF0F5132);
        icon = Icons.auto_awesome_rounded;
        break;
      default:
        bg = const Color(0xFFE6E2EE);
        text = const Color(0xFF4A3A59);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: text),
            const SizedBox(width: 6),
          ],
          Text(
            tier,
            style: TextStyle(color: text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
