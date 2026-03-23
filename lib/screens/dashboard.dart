import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/dashboard_repository.dart';
import '../services/orders_repository.dart';
import 'slider.dart';
import 'posBilling.dart';
import 'orders.dart';
import 'products.dart';
import 'Analytics.dart';
import 'customer.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'notifications.dart';
import '../loading/skeleton_dashboard.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

enum SalesRange { week, month, year }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _repository = DashboardRepository();
  final OrdersRepository _ordersRepository = OrdersRepository();
  final SupabaseClient _client = Supabase.instance.client;

  DashboardData? _data;
  List<OrderRecord> _orders = const [];
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;
  SalesRange _selectedRange = SalesRange.week;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Colour Palette ────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF2EEF9);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFF5B21B6);
  static const Color _accentLight = Color(0xFF7C3AED);
  static const Color _accentSoft = Color(0xFFEDE9FE);
  static const Color _accentMid = Color(0xFFDDD6FE);
  static const Color _textPrimary = Color(0xFF1A0F2E);
  static const Color _textSecondary = Color(0xFF6B5E85);
  static const Color _divider = Color(0xFFE9E2F6);
  static const Color _green = Color(0xFF047857);
  static const Color _greenSoft = Color(0xFFD1FAE5);
  static const Color _amber = Color(0xFFB45309);
  static const Color _amberSoft = Color(0xFFFEF3C7);
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _blueSoft = Color(0xFFDBEAFE);
  static const Color _red = Color(0xFFB91C1C);
  static const Color _redSoft = Color(0xFFFEE2E2);

  DashboardData get _fallbackData => const DashboardData(
    revenueToday: 0,
    ordersToday: 0,
    productsCount: 0,
    customersCount: 0,
    recentOrders: <RecentOrder>[],
    storeInfo: null,
    weekSales: <SalesPoint>[],
    monthSales: <SalesPoint>[],
    yearSales: <SalesPoint>[],
  );

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.fetch();
      List<OrderRecord> orders = const [];
      try {
        orders = await _ordersRepository.fetchOrders();
      } catch (_) {
        orders = const [];
      }
      if (!mounted) return;
      setState(() {
        _data = result;
        _orders = orders;
      });
      await _loadUnreadNotifications();
      _fadeController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
        query = query.eq('is_read', false).eq('store_id', storeId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false).eq('user_id', userId);
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

  @override
  Widget build(BuildContext context) {
    final data = _data ?? _fallbackData;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: DashboardDrawer(
        store: data.storeInfo,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
        onOpenPosBilling: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.posBilling,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenOrders: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.orders,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenProducts: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.products,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenCustomers: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.customers,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenAnalytics: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.analytics,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenVendors: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.vendors,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenAiUpload: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.aiUpload,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenDelivery: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.delivery,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenStoreSettings: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.storeSettings,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        activeDashboard: true,
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: RefreshIndicator(
          color: _accentLight,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: _loading
              ? const SkeletonDashboard()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      TopHeaderSliver(
                        backgroundColor: _bg,
                        accent: _accent,
                        unreadNotifications: _unreadNotifications,
                        onMenuPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        onNotificationsPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              )
                              .then((_) => _loadUnreadNotifications());
                        },
                        logoUrl: data.storeInfo?.logoUrl,
                        initials: _initials(data.storeInfo?.name ?? 'Store'),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (_error != null) _errorBanner(_error!),
                            const SizedBox(height: 4),
                            _welcomeCard(data.storeInfo),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              'At a Glance',
                              Icons.dashboard_customize_rounded,
                            ),
                            const SizedBox(height: 12),
                            _statsGrid(data),
                            const SizedBox(height: 20),
                            _sectionHeader('Quick Actions', Icons.bolt_rounded),
                            const SizedBox(height: 12),
                            _quickActions(),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              'Sales Overview',
                              Icons.bar_chart_rounded,
                            ),
                            const SizedBox(height: 12),
                            _salesOverview(data),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              'Recent Orders',
                              Icons.receipt_long_rounded,
                            ),
                            const SizedBox(height: 12),
                            _recentOrders(data.recentOrders),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              "Today's Summary",
                              Icons.today_rounded,
                            ),
                            const SizedBox(height: 12),
                            _todaySummary(data),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              'Tips & Insights',
                              Icons.tips_and_updates_rounded,
                            ),
                            const SizedBox(height: 12),
                            _tips(),
                            const SizedBox(height: 20),
                            _sectionHeader(
                              'Store Info',
                              Icons.storefront_rounded,
                            ),
                            const SizedBox(height: 12),
                            _storeInfoCard(data.storeInfo),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: _accentLight),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_divider, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Welcome Card ──────────────────────────────────────────────────────────
  Widget _welcomeCard(StoreInfo? store) {
    final storeName = store?.name ?? 'My Store';
    final category = store?.category ?? 'Retail';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _accentLight.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF34D399), size: 8),
                          SizedBox(width: 5),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$greeting 👋',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  storeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your store is open and ready for business.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _welcomePill(
                      Icons.point_of_sale_rounded,
                      'POS Billing',
                      onTap: () =>
                          ShellNav.switchTo(context, ShellTab.posBilling),
                    ),
                    const SizedBox(width: 10),
                    _welcomePill(
                      Icons.add_box_rounded,
                      'Add Product',
                      onTap: () =>
                          ShellNav.switchTo(context, ShellTab.products),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomePill(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Grid ────────────────────────────────────────────────────────────
  Widget _statsGrid(DashboardData data) {
    final totalOrders = _ordersTotalCount;
    final cards = [
      _StatCard(
        title: "Revenue Today",
        value: '₹${_formatCurrency(data.revenueToday)}',
        subtitle: data.revenueToday == 0 ? 'No orders yet' : 'Live total',
        icon: Icons.account_balance_wallet_rounded,
        tint: _green,
        softBg: _greenSoft,
      ),
      _StatCard(
        title: 'Orders',
        value: '$totalOrders',
        subtitle: totalOrders == 0 ? 'No orders yet' : 'Total orders',
        icon: Icons.shopping_bag_rounded,
        tint: _blue,
        softBg: _blueSoft,
      ),
      _StatCard(
        title: 'Products',
        value: '${data.productsCount}',
        subtitle: data.productsCount == 0 ? 'Add a product' : 'In your catalog',
        icon: Icons.inventory_2_rounded,
        tint: _accentLight,
        softBg: _accentSoft,
      ),
      _StatCard(
        title: 'Customers',
        value: '${data.customersCount}',
        subtitle: data.customersCount == 0 ? 'None yet' : 'Total base',
        icon: Icons.people_alt_rounded,
        tint: _amber,
        softBg: _amberSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: w, child: _statTile(c)))
              .toList(),
        );
      },
    );
  }

  Widget _statTile(_StatCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: card.softBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, size: 20, color: card.tint),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: card.softBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 12,
                  color: card.tint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            card.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            card.subtitle,
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _quickActions() {
    final actions = [
      _ActionItem(
        'Add Product',
        Icons.add_box_rounded,
        const Color(0xFF0284C7),
        const Color(0xFFE0F2FE),
        onTap: () => ShellNav.switchTo(context, ShellTab.products),
      ),
      _ActionItem(
        'POS Billing',
        Icons.point_of_sale_rounded,
        const Color(0xFF7C3AED),
        _accentSoft,
        onTap: () => ShellNav.switchTo(context, ShellTab.posBilling),
      ),
      _ActionItem(
        'AI Upload',
        Icons.auto_awesome_rounded,
        const Color(0xFFDB2777),
        const Color(0xFFFCE7F3),
      ),
      _ActionItem(
        'Delivery',
        Icons.local_shipping_rounded,
        const Color(0xFF059669),
        _greenSoft,
        onTap: () => ShellNav.switchTo(context, ShellTab.delivery),
      ),
      _ActionItem(
        'Analytics',
        Icons.insert_chart_rounded,
        const Color(0xFFD97706),
        _amberSoft,
        onTap: () => ShellNav.switchTo(context, ShellTab.analytics),
      ),
      _ActionItem(
        'Customers',
        Icons.people_alt_rounded,
        const Color(0xFF1D4ED8),
        _blueSoft,
        onTap: () => ShellNav.switchTo(context, ShellTab.customers),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: action.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: action.softBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: action.tint.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: action.tint.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, size: 22, color: action.tint),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: action.tint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sales Overview ────────────────────────────────────────────────────────
  Widget _salesOverview(DashboardData data) {
    final points = _seriesForRange(data);
    final rangeTotal = points.fold<double>(0, (s, p) => s + p.value);
    final hasSales = points.any((p) => p.value > 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${_formatCurrency(rangeTotal)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total this ${_rangeLabel(_selectedRange)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Range toggle
              Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _rangeChip('W', SalesRange.week),
                    _rangeChip('M', SalesRange.month),
                    _rangeChip('Y', SalesRange.year),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SalesChart(
            points: points,
            accent: _accentLight,
            formatValue: _formatCurrency,
          ),
          const SizedBox(height: 16),
          if (hasSales)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: _accentLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales refreshed automatically',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Totals from your recent orders',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 36,
                    color: _textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No sales data for this period',
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, SalesRange range) {
    final selected = _selectedRange == range;
    return GestureDetector(
      onTap: () {
        if (_selectedRange == range) return;
        setState(() => _selectedRange = range);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Recent Orders ─────────────────────────────────────────────────────────
  Widget _recentOrders(List<RecentOrder> orders) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${orders.length} order${orders.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ShellNav.switchTo(context, ShellTab.orders),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'View All →',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accentLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 32,
                      color: _accentLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No orders yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Orders will appear here once placed',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => Divider(height: 18, color: _divider),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accentSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: _accentLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${order.id} · ${_formatOrderDate(order.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_formatCurrency(order.total)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _statusChip(order.status),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Today's Summary ───────────────────────────────────────────────────────
  Widget _todaySummary(DashboardData data) {
    final peak = _computePeakHour(data.recentOrders);
    final totalOrders = _ordersTotalCount;
    final summaryItems = [
      _SummaryItem(
        "Revenue",
        '₹${_formatCurrency(data.revenueToday)}',
        Icons.account_balance_wallet_rounded,
        _green,
        _greenSoft,
      ),
      _SummaryItem(
        'Orders',
        '$totalOrders',
        Icons.shopping_bag_rounded,
        _blue,
        _blueSoft,
      ),
      _SummaryItem(
        'Products',
        '${data.productsCount}',
        Icons.inventory_2_rounded,
        _accentLight,
        _accentSoft,
      ),
      _SummaryItem(
        'Peak Hour',
        peak.range,
        Icons.access_time_rounded,
        _amber,
        _amberSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: summaryItems
              .map((item) => SizedBox(width: w, child: _summaryCard(item)))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.softBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: item.tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tips ──────────────────────────────────────────────────────────────────
  Widget _tips() {
    final tips = [
      _TipData(
        'Daily Delivery',
        'Set up recurring deliveries for loyal customers.',
        Icons.local_shipping_rounded,
        _green,
        _greenSoft,
      ),
      _TipData(
        'Fresh Stock',
        'Update stock daily to keep your catalog accurate.',
        Icons.inventory_rounded,
        _blue,
        _blueSoft,
      ),
      _TipData(
        'Expiry Tracking',
        'Monitor product shelf life to reduce waste.',
        Icons.alarm_rounded,
        _amber,
        _amberSoft,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: tips
            .map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: tip.softBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tip.icon, size: 18, color: tip.tint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tip.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Store Info Card ───────────────────────────────────────────────────────
  Widget _storeInfoCard(StoreInfo? store) {
    final info =
        store ??
        const StoreInfo(
          name: 'My Store',
          category: 'Retail',
          mode: 'Shop + Delivery',
          location: '—',
          status: 'Inactive',
        );
    final isActive = info.status.toLowerCase() == 'active';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        info.category,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      ShellNav.switchTo(context, ShellTab.storeSettings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.storefront_rounded, 'Store Name', info.name),
                _infoDivider(),
                _infoRow(Icons.category_rounded, 'Category', info.category),
                _infoDivider(),
                _infoRow(Icons.business_center_rounded, 'Mode', info.mode),
                _infoDivider(),
                _infoRow(Icons.location_on_rounded, 'Location', info.location),
                _infoDivider(),
                _infoRow(
                  Icons.circle_rounded,
                  'Status',
                  info.status,
                  valueColor: isActive ? _green : _textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _infoDivider() => Divider(height: 16, color: _divider, thickness: 1);

  // ── Status Chip ───────────────────────────────────────────────────────────
  Widget _statusChip(String status) {
    final n = status.toLowerCase();
    Color bg = const Color(0xFFF3F0F8);
    Color fg = _textSecondary;
    String label = status.isEmpty ? 'Pending' : status;

    if (n.contains('deliver') || n.contains('complete')) {
      bg = _greenSoft;
      fg = _green;
      label = 'Delivered';
    } else if (n.contains('cancel')) {
      bg = _redSoft;
      fg = _red;
      label = 'Cancelled';
    } else if (n.contains('pending')) {
      bg = _amberSoft;
      fg = _amber;
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  // ── Error Banner ──────────────────────────────────────────────────────────
  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amberSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: _amber, fontSize: 13)),
          ),
          TextButton(
            onPressed: _loadData,
            child: Text(
              'Retry',
              style: TextStyle(color: _amber, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _accent,
        unselectedItemColor: _textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
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
              onOpenDashboard: () =>
                  ShellNav.switchTo(context, ShellTab.dashboard),
              onOpenOrders: () => ShellNav.switchTo(context, ShellTab.orders),
              onOpenProducts: () =>
                  ShellNav.switchTo(context, ShellTab.products),
              onOpenPosBilling: () =>
                  ShellNav.switchTo(context, ShellTab.posBilling),
              onOpenAnalytics: () =>
                  ShellNav.switchTo(context, ShellTab.analytics),
              onOpenVendors: () => ShellNav.switchTo(context, ShellTab.vendors),
              activeModule: MoreActionsModule.dashboard,
              onOpenAiUpload: () =>
                  ShellNav.switchTo(context, ShellTab.aiUpload),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_rounded),
            label: 'Share',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<SalesPoint> _seriesForRange(DashboardData data) {
    final now = DateTime.now();
    switch (_selectedRange) {
      case SalesRange.week:
        return data.weekSales.isNotEmpty
            ? data.weekSales
            : _placeholderDays(now, 7);
      case SalesRange.month:
        return data.monthSales.isNotEmpty
            ? data.monthSales
            : _placeholderDays(now, 30);
      case SalesRange.year:
        return data.yearSales.isNotEmpty
            ? data.yearSales
            : _placeholderMonths(now.year);
    }
  }

  List<SalesPoint> _placeholderDays(DateTime now, int days) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().subtract(Duration(days: days - 1));
    return List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      return SalesPoint(
        date: date,
        value: 0,
        label: _weekdayLabel(date.weekday),
      );
    });
  }

  List<SalesPoint> _placeholderMonths(int year) {
    return List.generate(12, (i) {
      final date = DateTime.utc(year, i + 1, 1);
      return SalesPoint(date: date, value: 0, label: _monthLabel(date.month));
    });
  }

  String _rangeLabel(SalesRange r) => r == SalesRange.week
      ? 'week'
      : r == SalesRange.month
      ? 'month'
      : 'year';

  String _formatCurrency(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  int get _ordersTodayCount {
    if (_orders.isEmpty) return _data?.ordersToday ?? 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _orders.where((o) => !o.createdAt.toLocal().isBefore(start)).length;
  }

  int get _ordersTotalCount {
    if (_orders.isNotEmpty) return _orders.length;
    return _data?.ordersToday ?? 0;
  }

  String _formatOrderDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return 'Today ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${_twoDigits(local.day)} ${_monthLabel(local.month)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _weekdayLabel(int wd) {
    const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (wd >= 1 && wd <= 7) ? n[wd - 1] : '--';
  }

  String _monthLabel(int m) {
    const n = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? n[m - 1] : '--';
  }

  _PeakHour _computePeakHour(List<RecentOrder> orders) {
    if (orders.isEmpty) return const _PeakHour(range: '--', count: 0);
    final counts = <int, int>{};
    for (final o in orders) {
      final h = o.createdAt.toLocal().hour;
      counts[h] = (counts[h] ?? 0) + 1;
    }
    final peak = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final s = peak.key;
    final e = (s + 3) % 24;
    return _PeakHour(
      range: '${_formatHour(s)} - ${_formatHour(e)}',
      count: peak.value,
    );
  }

  String _formatHour(int h) {
    final n = h % 24;
    final suffix = n >= 12 ? 'PM' : 'AM';
    final h12 = n % 12 == 0 ? 12 : n % 12;
    return '$h12 $suffix';
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }
}

// ── Sales Chart ───────────────────────────────────────────────────────────────
class _SalesChart extends StatelessWidget {
  const _SalesChart({
    required this.points,
    required this.accent,
    required this.formatValue,
  });

  final List<SalesPoint> points;
  final Color accent;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(
      0,
      (max, p) => p.value > max ? p.value : max,
    );
    final safeMaxY = maxY <= 0 ? 1.0 : maxY;
    final ticks = _buildTicks(safeMaxY);
    final labelIndexes = _labelIndexes(points.length);

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ticks.reversed
                    .map(
                      (t) => Text(
                        '₹${formatValue(t)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9A8FA5),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _SalesAreaPainter(
                    points: points,
                    accent: accent,
                    maxY: safeMaxY,
                    ticks: ticks,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: labelIndexes
              .map(
                (index) => Expanded(
                  child: Text(
                    points[index].label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9A8FA5),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<double> _buildTicks(double maxY) {
    if (maxY <= 0) return const [0, 0.25, 0.5, 0.75, 1];
    final step = maxY / 4;
    return List.generate(5, (i) => step * i);
  }

  List<int> _labelIndexes(int length) {
    if (length <= 1) return [0];
    if (length <= 8) return List.generate(length, (i) => i);
    final set = <int>{0, length - 1};
    final step = (length - 1) / 6;
    for (int i = 1; i <= 5; i++) set.add((i * step).round());
    return set.toList()..sort();
  }
}

class _SalesAreaPainter extends CustomPainter {
  const _SalesAreaPainter({
    required this.points,
    required this.accent,
    required this.maxY,
    required this.ticks,
  });

  final List<SalesPoint> points;
  final Color accent;
  final double maxY;
  final List<double> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width, h = size.height;
    final baseline = h - 4;
    final drawableH = h - 12;

    final gridPaint = Paint()
      ..color = accent.withOpacity(0.07)
      ..strokeWidth = 1;
    for (final tick in ticks.where((v) => v > 0)) {
      final y = baseline - (tick / maxY) * drawableH;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final stepX = points.length <= 1 ? 0.0 : w / (points.length - 1);
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = stepX * i;
      final y = (baseline - (points[i].value / maxY) * drawableH).clamp(0.0, h);
      offsets.add(Offset(x, y.toDouble()));
    }

    final areaPath = Path()..moveTo(0, baseline);
    for (final o in offsets) areaPath.lineTo(o.dx, o.dy);
    areaPath.lineTo(w, baseline);
    areaPath.close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: [accent.withOpacity(0.18), accent.withOpacity(0.03)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) linePath.lineTo(o.dx, o.dy);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = accent;
    final dotBg = Paint()..color = Colors.white;
    for (final o in offsets) {
      canvas.drawCircle(o, 5, dotBg);
      canvas.drawCircle(o, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesAreaPainter old) =>
      old.points != points || old.accent != accent || old.maxY != maxY;
}

// ── Data helpers ──────────────────────────────────────────────────────────────
class _StatCard {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.softBg,
  });
  final String title, value, subtitle;
  final IconData icon;
  final Color tint, softBg;
}

class _ActionItem {
  const _ActionItem(
    this.label,
    this.icon,
    this.tint,
    this.softBg, {
    this.onTap,
  });
  final String label;
  final IconData icon;
  final Color tint, softBg;
  final VoidCallback? onTap;
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon, this.tint, this.softBg);
  final String label, value;
  final IconData icon;
  final Color tint, softBg;
}

class _TipData {
  const _TipData(this.title, this.subtitle, this.icon, this.tint, this.softBg);
  final String title, subtitle;
  final IconData icon;
  final Color tint, softBg;
}

class _PeakHour {
  const _PeakHour({required this.range, required this.count});
  final String range;
  final int count;
}
