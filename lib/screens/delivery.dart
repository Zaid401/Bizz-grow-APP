import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'slider.dart';
import 'store_settings.dart';
import 'notifications.dart';
import '../services/delivery_repository.dart';
import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

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
  static const inputFill = Color(0xFFFAF8FE);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFDBEAFE);
  static const purple = Color(0xFF6D28D9);
  static const purpleSoft = Color(0xFFEDE9FE);
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
}

enum DeliveryFilter { all, pending, inTransit, delivered }

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DeliveryRepository _repository = DeliveryRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final TextEditingController _search = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  List<DeliveryRecord> _deliveries = const [];
  StoreInfo? _storeInfo;
  bool _loading = true;
  String? _error;
  DeliveryFilter _filter = DeliveryFilter.all;
  int _unreadNotifications = 0;

  late AnimationController _fadeController;
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation<double>(1);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _repository.fetchDeliveries();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _deliveries = results;
        _storeInfo = dash.storeInfo;
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

  // ── Computed ───────────────────────────────────────────────────────────────
  List<DeliveryRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _deliveries.where((d) {
      final matchQ =
          q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.customer.toLowerCase().contains(q);
      final matchF = switch (_filter) {
        DeliveryFilter.all => true,
        DeliveryFilter.pending => d.status == DeliveryStatus.pending,
        DeliveryFilter.inTransit => d.status == DeliveryStatus.inTransit,
        DeliveryFilter.delivered =>
          d.status == DeliveryStatus.delivered ||
              d.status == DeliveryStatus.completed,
      };
      return matchQ && matchF;
    }).toList();
  }

  int get _total => _deliveries.length;
  int get _pending =>
      _deliveries.where((d) => d.status == DeliveryStatus.pending).length;
  int get _inTransit =>
      _deliveries.where((d) => d.status == DeliveryStatus.inTransit).length;
  int get _completed => _deliveries
      .where(
        (d) =>
            d.status == DeliveryStatus.delivered ||
            d.status == DeliveryStatus.completed,
      )
      .length;

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
        onOpenAnalytics: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.analytics,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenStoreSettings: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.storeSettings,
          closeDrawer: () => Navigator.of(context).pop(),
        ),
        onOpenDelivery: () => Navigator.of(context).pop(),
        activeDelivery: true,
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
                    _buildActionsRow(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      _buildErrorBanner()
                    else if (_loading)
                      _buildLoadingState()
                    else if (_filtered.isEmpty)
                      _buildEmptyState()
                    else
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: _filtered
                              .map(
                                (d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DeliveryCard(delivery: d),
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
            Icons.local_shipping_rounded,
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
                'Delivery Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track and manage all deliveries',
                style: TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Actions Row ────────────────────────────────────────────────────────────
  Widget _buildActionsRow() {
    return Row(
      children: [
        // Date picker button
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: _C.accentLight,
                ),
                SizedBox(width: 8),
                Text(
                  'Today',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _C.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Optimize route button
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alt_route_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Optimize Route',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats Grid ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        'Total',
        '$_total',
        Icons.local_shipping_rounded,
        _C.accentLight,
        _C.accentSoft,
      ),
      _StatData(
        'In Transit',
        '$_inTransit',
        Icons.moving_rounded,
        _C.purple,
        _C.purpleSoft,
      ),
      _StatData(
        'Completed',
        '$_completed',
        Icons.check_circle_rounded,
        _C.green,
        _C.greenSoft,
      ),
      _StatData(
        'Pending',
        '$_pending',
        Icons.hourglass_top_rounded,
        _C.amber,
        _C.amberSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map((s) => SizedBox(width: w, child: _buildStatCard(s)))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData s) {
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
              color: s.softBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(s.icon, color: s.tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _C.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: _C.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by order ID or customer…',
          hintStyle: TextStyle(
            color: _C.textSecondary.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _C.textSecondary,
            size: 20,
          ),
          suffixIcon: _search.text.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _search.clear()),
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
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _C.accentLight, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final chips = [
      _ChipData(DeliveryFilter.all, 'All', _C.accentLight, _C.accentSoft),
      _ChipData(DeliveryFilter.pending, 'Pending', _C.amber, _C.amberSoft),
      _ChipData(
        DeliveryFilter.inTransit,
        'In Transit',
        _C.purple,
        _C.purpleSoft,
      ),
      _ChipData(DeliveryFilter.delivered, 'Delivered', _C.green, _C.greenSoft),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          final active = _filter == c.filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = c.filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? c.bg : _C.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? c.color.withOpacity(0.4) : _C.divider,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: c.color.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                c.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? c.color : _C.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: CircularProgressIndicator(color: _C.accentLight),
    ),
  );

  Widget _buildEmptyState() => Container(
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
            Icons.local_shipping_rounded,
            size: 36,
            color: _C.accentLight,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No deliveries found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'New deliveries will appear here once created.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _C.textSecondary),
        ),
      ],
    ),
  );

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
        currentIndex: 0,
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
              activeModule: MoreActionsModule.vendors,
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

// ── Delivery Card ──────────────────────────────────────────────────────────────
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});
  final DeliveryRecord delivery;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(delivery.status);

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
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
          // ── Colour status strip ──────────────────────────────────────────────
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: style.softBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(style.icon, color: style.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.id,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _C.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: _C.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                delivery.customer,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _C.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: style.softBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: style.color.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: style.color,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            style.label,
                            style: TextStyle(
                              color: style.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Container(height: 1, color: _C.divider),
                const SizedBox(height: 12),

                // Info pills + action row
                Row(
                  children: [
                    _InfoPill(
                      icon: Icons.layers_rounded,
                      label: 'Items',
                      value: '${delivery.items}',
                      tint: _C.accentLight,
                      softBg: _C.accentSoft,
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: _timeAgo(delivery.createdAt),
                      tint: _C.purple,
                      softBg: _C.purpleSoft,
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Amount',
                      value: '₹${delivery.amount.toStringAsFixed(0)}',
                      tint: _C.green,
                      softBg: _C.greenSoft,
                    ),
                    const Spacer(),
                    // Call button
                    _ActionBtn(
                      icon: Icons.phone_rounded,
                      enabled: delivery.phone != null,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    // Navigate button
                    _ActionBtn(
                      icon: Icons.near_me_rounded,
                      enabled: true,
                      onTap: () {},
                      isPrimary: true,
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
}

// ── Info Pill ──────────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.softBg,
  });

  final IconData icon;
  final String label, value;
  final Color tint, softBg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: softBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: tint),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _C.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: _C.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Action Button ──────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final bool enabled, isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: !enabled
            ? _C.divider
            : isPrimary
            ? _C.accent
            : _C.accentSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: !enabled
              ? _C.divider
              : isPrimary
              ? _C.accent
              : _C.accentMid,
        ),
      ),
      child: Icon(
        icon,
        size: 17,
        color: !enabled
            ? _C.textSecondary
            : isPrimary
            ? Colors.white
            : _C.accentLight,
      ),
    ),
  );
}

// ── Data helpers ───────────────────────────────────────────────────────────────
class _StatData {
  const _StatData(this.label, this.value, this.icon, this.tint, this.softBg);
  final String label, value;
  final IconData icon;
  final Color tint, softBg;
}

class _ChipData {
  const _ChipData(this.filter, this.label, this.color, this.bg);
  final DeliveryFilter filter;
  final String label;
  final Color color, bg;
}

({String label, Color color, Color softBg, IconData icon}) _statusStyle(
  DeliveryStatus s,
) {
  switch (s) {
    case DeliveryStatus.pending:
      return (
        label: 'Pending',
        color: _C.amber,
        softBg: _C.amberSoft,
        icon: Icons.hourglass_top_rounded,
      );
    case DeliveryStatus.inTransit:
      return (
        label: 'In Transit',
        color: _C.purple,
        softBg: _C.purpleSoft,
        icon: Icons.moving_rounded,
      );
    case DeliveryStatus.delivered:
      return (
        label: 'Delivered',
        color: _C.green,
        softBg: _C.greenSoft,
        icon: Icons.done_all_rounded,
      );
    case DeliveryStatus.completed:
      return (
        label: 'Completed',
        color: _C.green,
        softBg: _C.greenSoft,
        icon: Icons.check_circle_rounded,
      );
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().toUtc().difference(date.toUtc());
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'B';
  final parts = t.split(RegExp(r'\s+'));
  final f = parts.first.isNotEmpty ? parts.first[0] : '';
  final l = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  final c = (f + l).toUpperCase();
  return c.isEmpty ? t[0].toUpperCase() : c;
}
