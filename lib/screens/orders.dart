import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'slider.dart';
import 'dashboard.dart';
import 'posBilling.dart';
import 'products.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'notifications.dart';
import '../services/orders_repository.dart';
import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/order_detail_screen.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';
import 'package:bizz_grow/models/order_types.dart';

// ── Shared Palette ────────────────────────────────────────────────────────────
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
  static const inputFill = Color(0xFFFAF8FE);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFDBEAFE);
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
  static const pink = Color(0xFFDB2777);
  static const pinkSoft = Color(0xFFFCE7F3);
}

enum OrderTimeline {
  allTime,
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OrderChannel _selectedChannel = OrderChannel.all;
  OrderStatus _selectedStatus = OrderStatus.all;
  OrderTimeline _selectedTimeline = OrderTimeline.allTime;
  final TextEditingController _searchCtrl = TextEditingController();

  final OrdersRepository _repository = OrdersRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final SupabaseClient _client = Supabase.instance.client;

  StoreInfo? _storeInfo;
  List<OrderRecord> _orders = const [];
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

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
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _repository.fetchOrders();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _orders = results;
        _storeInfo = dash.storeInfo;
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

  // ── Filtered list ─────────────────────────────────────────────────────────
  List<OrderRecord> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _orders.where((o) {
      final channelOk =
          _selectedChannel == OrderChannel.all || o.channel == _selectedChannel;
      final statusOk =
          _selectedStatus == OrderStatus.all || o.status == _selectedStatus;
      final timelineOk = _matchesTimeline(o.createdAt);
      final searchOk =
          q.isEmpty ||
          o.customer.toLowerCase().contains(q) ||
          o.amount.toString().contains(q);
      return channelOk && statusOk && timelineOk && searchOk;
    }).toList();
  }

  bool _matchesTimeline(DateTime createdAt) {
    if (_selectedTimeline == OrderTimeline.allTime) return true;
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_selectedTimeline) {
      case OrderTimeline.today:
        return !local.isBefore(todayStart);
      case OrderTimeline.yesterday:
        final ys = todayStart.subtract(const Duration(days: 1));
        return !local.isBefore(ys) && local.isBefore(todayStart);
      case OrderTimeline.last7Days:
        return !local.isBefore(todayStart.subtract(const Duration(days: 6)));
      case OrderTimeline.last30Days:
        return !local.isBefore(todayStart.subtract(const Duration(days: 29)));
      case OrderTimeline.thisMonth:
        return local.year == now.year && local.month == now.month;
      case OrderTimeline.allTime:
        return true;
    }
  }

  String _timelineLabel(OrderTimeline t) {
    switch (t) {
      case OrderTimeline.allTime:
        return 'All Time';
      case OrderTimeline.today:
        return 'Today';
      case OrderTimeline.yesterday:
        return 'Yesterday';
      case OrderTimeline.last7Days:
        return 'Last 7 Days';
      case OrderTimeline.last30Days:
        return 'Last 30 Days';
      case OrderTimeline.thisMonth:
        return 'This Month';
    }
  }

  void _showTimelineMenu(TapDownDetails details) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<OrderTimeline>(
      context: context,
      position: position,
      color: _C.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: OrderTimeline.values
          .map(
            (t) => PopupMenuItem<OrderTimeline>(
              value: t,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: _TimelineMenuItem(
                label: _timelineLabel(t),
                selected: _selectedTimeline == t,
              ),
            ),
          )
          .toList(),
    );
    if (selected == null || selected == _selectedTimeline) return;
    setState(() => _selectedTimeline = selected);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalOrders = _orders.length;
    final onlineOrders = _orders
        .where((o) => o.channel == OrderChannel.online)
        .length;
    final walkInOrders = _orders
        .where((o) => o.channel == OrderChannel.walkIn)
        .length;
    final pendingOrders = _orders
        .where((o) => o.status == OrderStatus.pending)
        .length;

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
        onOpenAnalytics: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.analytics,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenVendors: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.vendors,
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
        onOpenOrders: () {},
        activeOrders: true,
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
                    _buildFilterRow(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(
                      totalOrders,
                      onlineOrders,
                      walkInOrders,
                      pendingOrders,
                    ),
                    const SizedBox(height: 16),
                    _buildChannelTabs(),
                    const SizedBox(height: 12),
                    _buildStatusChips(),
                    const SizedBox(height: 14),
                    _buildSearchRow(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      _buildErrorBanner()
                    else if (_loading)
                      _buildLoadingState()
                    else if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      FadeTransition(
                        opacity:
                            _fadeAnimation ?? const AlwaysStoppedAnimation(1),
                        child: Column(
                          children: filtered
                              .map(
                                (order) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _OrderCard(
                                    order: order,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            OrderDetailScreen(order: order),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
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

  // ── Title Row ─────────────────────────────────────────────────────────────
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
            Icons.shopping_bag_rounded,
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
                'Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage and track customer orders',
                style: TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Filter Row ────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Row(
      children: [
        // Timeline dropdown
        GestureDetector(
          onTapDown: _showTimelineMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
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
                const Icon(
                  Icons.calendar_today_rounded,
                  color: _C.accentLight,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _timelineLabel(_selectedTimeline),
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _C.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Export button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_rounded, color: _C.accentLight, size: 16),
              SizedBox(width: 8),
              Text(
                'Export',
                style: TextStyle(
                  color: _C.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Order count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filtered.length} orders',
            style: const TextStyle(
              fontSize: 12,
              color: _C.accentLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats Grid ────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(int total, int online, int walkIn, int pending) {
    final items = [
      _StatData(
        'Total',
        '$total',
        Icons.shopping_bag_rounded,
        _C.accentLight,
        _C.accentSoft,
      ),
      _StatData(
        'Online',
        '$online',
        Icons.language_rounded,
        _C.blue,
        _C.blueSoft,
      ),
      _StatData(
        'Walk-in',
        '$walkIn',
        Icons.storefront_rounded,
        _C.green,
        _C.greenSoft,
      ),
      _StatData(
        'Pending',
        '$pending',
        Icons.hourglass_top_rounded,
        _C.amber,
        _C.amberSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(width: w, child: _buildStatCard(item)))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: d.softBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(d.icon, color: d.tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d.label,
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Channel Tabs ──────────────────────────────────────────────────────────
  Widget _buildChannelTabs() {
    final tabs = [
      _TabData(Icons.shopping_bag_rounded, 'All', OrderChannel.all),
      _TabData(Icons.language_rounded, 'Online', OrderChannel.online),
      _TabData(Icons.storefront_rounded, 'Walk-in', OrderChannel.walkIn),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
      ),
      child: Row(
        children: [
          ...tabs.map((tab) {
            final active = _selectedChannel == tab.channel;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedChannel = tab.channel),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? _C.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 15,
                        color: active ? Colors.white : _C.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _C.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          // Broadcast / alert button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: _C.accentLight,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Chips ──────────────────────────────────────────────────────────
  Widget _buildStatusChips() {
    final statuses = [
      _ChipData('All', OrderStatus.all, _C.accentSoft, _C.accentLight),
      _ChipData('Pending', OrderStatus.pending, _C.amberSoft, _C.amber),
      _ChipData('Confirmed', OrderStatus.confirmed, _C.blueSoft, _C.blue),
      _ChipData('Delivering', OrderStatus.delivering, _C.pinkSoft, _C.pink),
      _ChipData('Delivered', OrderStatus.delivered, _C.greenSoft, _C.green),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = statuses[index];
          final active = _selectedStatus == chip.status;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = chip.status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? chip.activeBg : _C.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? chip.activeColor.withOpacity(0.4)
                      : _C.divider,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: chip.activeColor.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                chip.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? chip.activeColor : _C.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Search Row ────────────────────────────────────────────────────────────
  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: _C.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by customer or amount…',
                hintStyle: TextStyle(
                  color: _C.textSecondary.withOpacity(0.5),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _C.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _searchCtrl.clear()),
                        child: const Icon(
                          Icons.close_rounded,
                          color: _C.textSecondary,
                          size: 18,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _C.accentLight,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: _C.accentLight,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ── Empty / Loading / Error ───────────────────────────────────────────────
  Widget _buildLoadingState() => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: CircularProgressIndicator(color: _C.accentLight),
    ),
  );

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: _C.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 36,
              color: _C.accentLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No orders found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different filter or time range.',
            style: TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
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
            child: Text(
              _error!,
              style: TextStyle(fontSize: 13, color: _C.amber),
            ),
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
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
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
        currentIndex: 1,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _C.accent,
        unselectedItemColor: _C.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 0)
            ShellNav.switchTo(context, ShellTab.dashboard);
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
              onOpenVendors: () => ShellNav.switchTo(context, ShellTab.vendors),
              activeModule: MoreActionsModule.orders,
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

// ── Order Card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onTap});

  final OrderRecord order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOnline = order.channel == OrderChannel.online;
    final statusStyle = _statusStyle(order.status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.divider),
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
              // ── Top colour strip ─────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusStyle.color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pills row
                    Row(
                      children: [
                        _pill(
                          isOnline
                              ? Icons.language_rounded
                              : Icons.storefront_rounded,
                          isOnline ? 'Online' : 'Walk-in',
                          isOnline ? _C.blue : _C.green,
                          isOnline ? _C.blueSoft : _C.greenSoft,
                        ),
                        const SizedBox(width: 6),
                        _pill(
                          statusStyle.icon,
                          _statusLabel(order.status),
                          statusStyle.color,
                          statusStyle.softBg,
                        ),
                        const SizedBox(width: 6),
                        _pill(
                          Icons.payment_rounded,
                          order.paymentMethod,
                          _C.accentLight,
                          _C.accentSoft,
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(order.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _C.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Customer & meta row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _C.accentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: _C.accentLight,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: _C.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.items} item${order.items == 1 ? '' : 's'} · ${_dateLabel(order.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${order.amount}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        _actionBtn(Icons.phone_rounded, 'Call'),
                        const SizedBox(width: 8),
                        _actionBtn(Icons.chat_rounded, 'Chat'),
                        const Spacer(),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _C.accentSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _C.accentMid),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  size: 14,
                                  color: _C.accentLight,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _C.accentLight,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _C.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  ({Color color, Color softBg, IconData icon}) _statusStyle(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return (
          color: _C.amber,
          softBg: _C.amberSoft,
          icon: Icons.hourglass_top_rounded,
        );
      case OrderStatus.confirmed:
        return (
          color: _C.blue,
          softBg: _C.blueSoft,
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.delivering:
        return (
          color: _C.pink,
          softBg: _C.pinkSoft,
          icon: Icons.local_shipping_rounded,
        );
      case OrderStatus.delivered:
        return (
          color: _C.green,
          softBg: _C.greenSoft,
          icon: Icons.done_all_rounded,
        );
      case OrderStatus.all:
        return (
          color: _C.accentLight,
          softBg: _C.accentSoft,
          icon: Icons.list_rounded,
        );
    }
  }
}

// ── Timeline menu item ────────────────────────────────────────────────────────
class _TimelineMenuItem extends StatelessWidget {
  const _TimelineMenuItem({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _C.accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (selected)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_rounded, size: 14, color: _C.accentLight),
            ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? _C.accentLight : _C.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────
class _StatData {
  const _StatData(this.label, this.value, this.icon, this.tint, this.softBg);
  final String label, value;
  final IconData icon;
  final Color tint, softBg;
}

class _TabData {
  const _TabData(this.icon, this.label, this.channel);
  final IconData icon;
  final String label;
  final OrderChannel channel;
}

class _ChipData {
  const _ChipData(this.label, this.status, this.activeBg, this.activeColor);
  final String label;
  final OrderStatus status;
  final Color activeBg, activeColor;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.confirmed:
      return 'Confirmed';
    case OrderStatus.delivering:
      return 'Delivering';
    case OrderStatus.delivered:
      return 'Delivered';
    case OrderStatus.all:
      return 'All';
  }
}

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().toUtc().difference(createdAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}

String _dateLabel(DateTime createdAt) {
  final l = createdAt.toLocal();
  const months = [
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
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final min = l.minute.toString().padLeft(2, '0');
  final p = l.hour >= 12 ? 'PM' : 'AM';
  return '${months[l.month - 1]} ${l.day}, $h:$min $p';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
