import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'customer.dart';
import 'slider.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'notifications.dart';
import '../loading/skeleton_analytics.dart';
import '../services/dashboard_repository.dart';
import '../services/orders_repository.dart';
import '../services/products_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';
import 'package:bizz_grow/models/order_types.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF2EEF9);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF5B21B6);
  static const accentLight = Color(0xFF7C3AED);
  static const accentSoft = Color(0xFFEDE9FE);
  static const accentMid = Color(0xFFDDD6FE);
  static const textPrimary = Color(0xFF1A0F2E);
  static const textSecondary = Color(0xFF6B5E85);
  static const divider = Color(0xFFE9E2F6);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFDBEAFE);
  static const pink = Color(0xFFDB2777);
  static const pinkSoft = Color(0xFFFCE7F3);
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
  static const purple = Color(0xFF6D28D9);
  static const purpleSoft = Color(0xFFEDE9FE);

  // Chart palette
  static const chart1 = Color(0xFF7C3AED);
  static const chart2 = Color(0xFF2563EB);
  static const chart3 = Color(0xFF059669);
  static const chart4 = Color(0xFFD97706);
}

enum AnalyticsRange { week, month, year }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final OrdersRepository _ordersRepository = OrdersRepository();
  final ProductsRepository _productsRepository = ProductsRepository();
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  StoreInfo? _storeInfo;
  int _unreadNotifications = 0;

  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _avgOrderValue = 0;
  int _totalCustomers = 0;
  int _onlineOrders = 0;
  int _walkInOrders = 0;
  int _deliveredOrders = 0;

  List<SalesPoint> _weekSales = const [];
  List<SalesPoint> _monthSales = const [];
  List<SalesPoint> _yearSales = const [];
  Map<String, int> _categoryBreakdown = const {};

  AnalyticsRange _range = AnalyticsRange.week;

  AnimationController? _fadeController;
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation<double>(1);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeOut,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dash = await _dashboardRepository.fetch();
      final orders = await _ordersRepository.fetchOrders();
      final products = await _productsRepository.fetchProducts();

      double revenue = 0;
      int online = 0, walkIn = 0, delivered = 0;
      for (final o in orders) {
        revenue += o.amount;
        if (o.channel == OrderChannel.walkIn)
          walkIn++;
        else
          online++;
        if (o.status == OrderStatus.delivered) delivered++;
      }

      final cats = <String, int>{};
      for (final p in products) {
        final name = p.categoryTag.isNotEmpty ? p.categoryTag : p.category;
        if (name.isEmpty) continue;
        cats[name] = (cats[name] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _storeInfo = dash.storeInfo;
        _totalRevenue = revenue;
        _totalOrders = orders.length;
        _avgOrderValue = orders.isEmpty ? 0 : revenue / orders.length;
        _totalCustomers = dash.customersCount;
        _onlineOrders = online;
        _walkInOrders = walkIn;
        _deliveredOrders = delivered;
        _weekSales = dash.weekSales;
        _monthSales = dash.monthSales;
        _yearSales = dash.yearSales;
        _categoryBreakdown = cats;
      });
      await _loadUnreadNotifications();
      _fadeController?.forward(from: 0);
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
        dynamic q = _client.from('notifications').select('id');
        q = q
            .eq('is_read', false)
            .or('store_id.eq.$storeId,user_id.eq.$userId');
        rows = ((await q) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic q = _client.from('notifications').select('id');
        q = q.eq('is_read', false).eq('store_id', storeId);
        rows = ((await q) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && userId != null) {
        dynamic q = _client.from('notifications').select('id');
        q = q.eq('is_read', false).eq('user_id', userId);
        rows = ((await q) as List)
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

  List<SalesPoint> get _activeSales => switch (_range) {
    AnalyticsRange.week => _weekSales,
    AnalyticsRange.month => _monthSales,
    AnalyticsRange.year => _yearSales,
  };

  double get _activeSalesTotal => _activeSales.fold(0, (a, b) => a + b.value);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bg,
      drawer: DashboardDrawer(
        onClose: () => Navigator.of(context).pop(),
        store: _storeInfo,
        onOpenDashboard: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.dashboard,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenPosBilling: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.posBilling,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenOrders: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.orders,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenProducts: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.products,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenCustomers: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.customers,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenDelivery: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.delivery,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenStoreSettings: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.storeSettings,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenAnalytics: () => Navigator.of(context).pop(),
        activeAnalytics: true,
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: RefreshIndicator(
          color: _C.accentLight,
          backgroundColor: _C.surface,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              TopHeaderSliver(
                backgroundColor: _C.bg,
                accent: _C.accent,
                unreadNotifications: _unreadNotifications,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    )
                    .then((_) => _loadUnreadNotifications()),
                logoUrl: _storeInfo?.logoUrl,
                initials: _initials(_storeInfo?.name ?? 'Store'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildTitleRow(),
                    const SizedBox(height: 16),
                    _buildFiltersRow(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      _buildErrorBanner()
                    else if (_loading)
                      _buildLoadingState()
                    else
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            _buildSummaryGrid(),
                            const SizedBox(height: 16),
                            _buildSalesOverview(),
                            const SizedBox(height: 16),
                            _buildOrderSources(),
                            const SizedBox(height: 16),
                            _buildTopProducts(),
                            const SizedBox(height: 16),
                            _buildCategoryBreakdown(),
                            const SizedBox(height: 16),
                            _buildPerformanceSummary(),
                          ],
                        ),
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

  // ── Title Row ──────────────────────────────────────────────────────────────
  Widget _buildTitleRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.accentLight, _C.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _C.accent.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.bar_chart_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track your store performance',
                style: TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Filters Row ────────────────────────────────────────────────────────────
  Widget _buildFiltersRow() {
    return Row(
      children: [
        _filterBtn(
          Icons.calendar_today_rounded,
          'All Time',
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: _C.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        _filterBtn(Icons.download_rounded, 'Export'),
      ],
    );
  }

  Widget _filterBtn(IconData icon, String label, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.accentLight, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _C.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ],
      ),
    );
  }

  // ── Summary Grid ───────────────────────────────────────────────────────────
  Widget _buildSummaryGrid() {
    final cards = [
      _SummaryData(
        'Total Revenue',
        '₹${_fmt(_totalRevenue)}',
        'From $_totalOrders orders',
        Icons.currency_rupee_rounded,
        _C.green,
        _C.greenSoft,
      ),
      _SummaryData(
        'Total Orders',
        '$_totalOrders',
        'All channels',
        Icons.shopping_bag_rounded,
        _C.blue,
        _C.blueSoft,
      ),
      _SummaryData(
        'Avg Order Value',
        '₹${_fmt(_avgOrderValue)}',
        'Per order',
        Icons.trending_up_rounded,
        _C.purple,
        _C.purpleSoft,
      ),
      _SummaryData(
        'Total Customers',
        '$_totalCustomers',
        'Active customers',
        Icons.groups_rounded,
        _C.amber,
        _C.amberSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((c) => SizedBox(width: w, child: _summaryCard(c)))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(_SummaryData d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _C.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: d.softBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(d.icon, color: d.tint, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.arrow_upward_rounded, size: 12, color: _C.green),
              const SizedBox(width: 3),
              Text(
                d.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: _C.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sales Overview ─────────────────────────────────────────────────────────
  Widget _buildSalesOverview() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.show_chart_rounded, 'Sales Overview'),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt(_activeSalesTotal)} from $_totalOrders orders',
            style: const TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 16),
          // Range tabs
          _RangeTabs(
            range: _range,
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: 14),
          // Chart
          _SalesChart(series: _activeSales),
        ],
      ),
    );
  }

  // ── Order Sources ──────────────────────────────────────────────────────────
  Widget _buildOrderSources() {
    final total = _onlineOrders + _walkInOrders;
    final onlinePct = total == 0 ? 0.0 : _onlineOrders / total;
    final walkInPct = total == 0 ? 0.0 : _walkInOrders / total;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.donut_large_rounded, 'Order Sources'),
          const SizedBox(height: 4),
          const Text(
            'Online vs Walk-in breakdown',
            style: TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 16),
          // Donut
          Center(
            child: _DonutChart(
              data: {'Online': _onlineOrders, 'Walk-in': _walkInOrders},
              colors: const [_C.blue, _C.accentLight],
              size: 180,
            ),
          ),
          const SizedBox(height: 16),
          // Legend with %
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(
                _C.blue,
                'Online',
                '$_onlineOrders (${(onlinePct * 100).toStringAsFixed(0)}%)',
              ),
              const SizedBox(width: 20),
              _legendItem(
                _C.accentLight,
                'Walk-in',
                '$_walkInOrders (${(walkInPct * 100).toStringAsFixed(0)}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top Products ───────────────────────────────────────────────────────────
  Widget _buildTopProducts() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.emoji_events_rounded, 'Top Selling Products'),
          const SizedBox(height: 4),
          const Text(
            'By quantity sold',
            style: TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: _C.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _C.accentLight,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No sales data yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Category Breakdown ─────────────────────────────────────────────────────
  Widget _buildCategoryBreakdown() {
    final hasData = _categoryBreakdown.isNotEmpty;
    final list = _categoryBreakdown.entries.toList();
    const colors = [
      _C.accent,
      _C.accentLight,
      _C.blue,
      _C.purple,
      _C.green,
      _C.amber,
      _C.pink,
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.pie_chart_rounded, 'Products by Category'),
          const SizedBox(height: 4),
          const Text(
            'Distribution of your catalogue',
            style: TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: _DonutChart(
              data: hasData ? Map.fromEntries(list) : const {'': 1},
              colors: colors,
              size: 180,
            ),
          ),
          const SizedBox(height: 14),
          if (hasData)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (var i = 0; i < list.length; i++)
                  _legendItem(
                    colors[i % colors.length],
                    list[i].key,
                    '${list[i].value}',
                  ),
              ],
            )
          else
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No category data yet',
                  style: TextStyle(
                    color: _C.accentLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Performance Summary ────────────────────────────────────────────────────
  Widget _buildPerformanceSummary() {
    final completionRate = _totalOrders == 0
        ? 0.0
        : _deliveredOrders / _totalOrders;

    final rows = [
      _PerfData(
        'Order Completion',
        '${(completionRate * 100).toStringAsFixed(0)}%',
        completionRate.clamp(0, 1).toDouble(),
        _C.green,
        _C.greenSoft,
      ),
      _PerfData(
        'Online Orders',
        '$_onlineOrders',
        _clampPercent(_onlineOrders, _onlineOrders + _walkInOrders),
        _C.blue,
        _C.blueSoft,
      ),
      _PerfData(
        'Walk-in Orders',
        '$_walkInOrders',
        _clampPercent(_walkInOrders, _onlineOrders + _walkInOrders),
        _C.purple,
        _C.purpleSoft,
      ),
      _PerfData(
        'Customer Base',
        '$_totalCustomers',
        _totalCustomers == 0 ? 0 : 1,
        _C.amber,
        _C.amberSoft,
      ),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.speed_rounded, 'Performance Summary'),
          const SizedBox(height: 16),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ProgressRow(data: r),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared card wrapper ────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _C.accentLight, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.divider, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Legend item ────────────────────────────────────────────────────────────
  Widget _legendItem(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() => const SkeletonAnalytics();

  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.amberSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.amber.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: _C.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_error!, style: TextStyle(fontSize: 13, color: _C.amber)),
        ),
        TextButton(
          onPressed: _load,
          child: Text(
            'Retry',
            style: TextStyle(color: _C.amber, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.divider)),
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
        currentIndex: 4,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _C.accent,
        unselectedItemColor: _C.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 0)
            ShellNav.switchTo(context, ShellTab.dashboard);
          else if (index == 1)
            ShellNav.switchTo(context, ShellTab.orders);
          else if (index == 2)
            ShellNav.switchTo(context, ShellTab.products);
          else if (index == 4) {
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
              activeModule: MoreActionsModule.analytics,
              onOpenAiUpload: () =>
                  ShellNav.switchTo(context, ShellTab.products),
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
}

// ── Range Tabs ─────────────────────────────────────────────────────────────────
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.range, required this.onChanged});
  final AnalyticsRange range;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.divider),
      ),
      child: Row(
        children: [
          _tab('Week', AnalyticsRange.week),
          _tab('Month', AnalyticsRange.month),
          _tab('Year', AnalyticsRange.year),
        ],
      ),
    );
  }

  Widget _tab(String label, AnalyticsRange value) {
    final active = range == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _C.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sales Chart ────────────────────────────────────────────────────────────────
class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.series});
  final List<SalesPoint> series;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: CustomPaint(
        painter: _SalesChartPainter(series: series),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  _SalesChartPainter({required this.series});
  final List<SalesPoint> series;

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = _C.accentLight;

    if (series.isEmpty) {
      final p = Paint()
        ..color = lineColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(0, size.height * 0.8),
        Offset(size.width, size.height * 0.8),
        p,
      );
      return;
    }

    final values = series.map((p) => p.value).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.01 ? 1.0 : maxV - minV;
    final denom = (series.length - 1).clamp(1, 9999);

    final pts = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final x = i / denom * size.width;
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * (size.height * 0.75) - size.height * 0.1;
      pts.add(Offset(x, y));
    }

    // Smooth curve via cubic bezier
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    // Area fill
    final areaPath = Path.from(linePath)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: [lineColor.withOpacity(0.18), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots with white ring
    for (final pt in pts) {
      canvas.drawCircle(pt, 5, Paint()..color = _C.surface);
      canvas.drawCircle(pt, 4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter old) => old.series != series;
}

// ── Progress Row ───────────────────────────────────────────────────────────────
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.data});
  final _PerfData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: data.tint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: data.softBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                data.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: data.tint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: data.percent,
            minHeight: 8,
            backgroundColor: _C.divider,
            valueColor: AlwaysStoppedAnimation<Color>(data.tint),
          ),
        ),
      ],
    );
  }
}

// ── Donut Chart (unchanged logic, refined colors) ──────────────────────────────
class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.data,
    required this.colors,
    required this.size,
  });
  final Map<String, int> data;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DonutPainter(data: data, colors: colors),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.data, required this.colors});
  final Map<String, int> data;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final stroke = size.width * 0.13;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _C.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (total <= 0) return;

    double start = -90;
    var idx = 0;
    for (final e in data.entries) {
      final sweep = e.value / total * 360;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start * 3.14159265 / 180,
        sweep * 3.14159265 / 180,
        false,
        Paint()
          ..color = colors[idx % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
      idx++;
    }

    // Centre label
    final tp = TextPainter(
      text: TextSpan(
        text: '$total',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _C.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.data != data || old.colors != colors;
}

// ── Data classes ───────────────────────────────────────────────────────────────
class _SummaryData {
  const _SummaryData(
    this.label,
    this.value,
    this.subtitle,
    this.icon,
    this.tint,
    this.softBg,
  );
  final String label, value, subtitle;
  final IconData icon;
  final Color tint, softBg;
}

class _PerfData {
  const _PerfData(this.label, this.value, this.percent, this.tint, this.softBg);
  final String label, value;
  final double percent;
  final Color tint, softBg;
}

// ── Helpers ────────────────────────────────────────────────────────────────────
double _clampPercent(int part, int total) {
  if (total <= 0) return 0;
  return (part / total).clamp(0, 1).toDouble();
}

String _fmt(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
