import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications.dart';
import 'slider.dart';
import '../services/vendors_repository.dart';
import '../services/dashboard_repository.dart';
import '../widgets/top_header.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/shell_nav.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
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
}

enum VendorsTab { vendors, purchases, payments }

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final VendorsRepository _repository = VendorsRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();

  List<VendorRecord> _vendors = const [];
  List<PurchaseRecord> _purchases = const [];
  StoreInfo? _storeInfo;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;
  VendorsTab _tab = VendorsTab.vendors;

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
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
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _repository.fetchVendors();
      final purchases = await _repository.fetchPurchases();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _vendors = results;
        _purchases = purchases;
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

  List<VendorRecord> get _filteredVendors {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _vendors;
    return _vendors.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.phone.toLowerCase().contains(q) ||
          v.email.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q);
    }).toList();
  }

  int get _totalVendors => _vendors.length;
  int get _totalPurchases => _purchases.length;
  double get _amountSpent =>
      _purchases.fold(0, (sum, p) => sum + p.totalAmount);
  double get _thisMonth {
    final now = DateTime.now();
    return _purchases
        .where(
          (p) =>
              p.purchaseDate.year == now.year &&
              p.purchaseDate.month == now.month,
        )
        .fold(0, (sum, p) => sum + p.totalAmount);
  }

  String get _topVendor {
    if (_purchases.isEmpty) return '—';
    final totals = <String, double>{};
    for (final p in _purchases) {
      final name = _vendorName(p.vendorId, p.vendorName);
      totals[name] = (totals[name] ?? 0) + p.totalAmount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double get _pendingPayment => _purchases.fold(0, (sum, p) {
    final status = p.paymentStatus.toLowerCase();
    if (status == 'paid') return sum;
    return sum + p.totalAmount;
  });

  String _vendorName(String vendorId, String fallback) {
    final match = _vendors.where((v) => v.id == vendorId).toList();
    if (match.isNotEmpty) return match.first.name;
    if (fallback.isNotEmpty && fallback != 'Vendor') return fallback;
    return 'Vendor';
  }

  Future<void> _showAddVendorSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddVendorSheet(repository: _repository),
    );

    if (created == true) {
      _load();
    }
  }

  Future<void> _showAddPurchaseSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RecordPurchaseSheet(repository: _repository, vendors: _vendors),
    );

    if (created == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bg,
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
        onOpenCustomers: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.customers,
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
        onOpenVendors: () => Navigator.of(context).pop(),
        activeVendors: true,
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
                    const SizedBox(height: 12),
                    _buildActionRow(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    _buildTabs(),
                    const SizedBox(height: 12),
                    if (_tab == VendorsTab.vendors) ...[
                      _buildSearch(),
                      const SizedBox(height: 14),
                      if (_error != null)
                        _buildErrorBanner()
                      else if (_loading)
                        _buildLoadingState()
                      else if (_filteredVendors.isEmpty)
                        _buildEmptyState()
                      else
                        FadeTransition(
                          opacity:
                              _fadeAnimation ?? const AlwaysStoppedAnimation(1),
                          child: Column(
                            children: _filteredVendors
                                .map(
                                  (vendor) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _vendorCard(vendor),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ] else
                      _buildComingSoon(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
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
            Icons.storefront_rounded,
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
                'Vendors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track purchases from your distributors & suppliers',
                style: TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _pillButton(
            label: 'Purchase',
            icon: Icons.payments_rounded,
            filled: false,
            onTap: _showAddPurchaseSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pillButton(
            label: 'Vendor',
            icon: Icons.add_rounded,
            filled: true,
            onTap: _showAddVendorSheet,
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final fg = filled ? Colors.white : _C.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled ? _C.accent : _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? _C.accent : _C.divider),
            boxShadow: [
              if (filled)
                BoxShadow(
                  color: _C.accent.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final cards = [
      _StatData(
        title: 'Total Vendors',
        value: _totalVendors.toString(),
        icon: Icons.groups_rounded,
        tint: _C.accent,
        softBg: _C.accentSoft,
      ),
      _StatData(
        title: 'Total Purchases',
        value: _totalPurchases.toString(),
        icon: Icons.receipt_long_rounded,
        tint: _C.blue,
        softBg: _C.blueSoft,
      ),
      _StatData(
        title: 'Amount Spent',
        value: '₹${_formatCurrency(_amountSpent)}',
        icon: Icons.currency_rupee_rounded,
        tint: _C.green,
        softBg: _C.greenSoft,
      ),
      _StatData(
        title: 'This Month',
        value: '₹${_formatCurrency(_thisMonth)}',
        icon: Icons.calendar_month_rounded,
        tint: _C.blue,
        softBg: _C.blueSoft,
      ),
      _StatData(
        title: 'Top Vendor',
        value: _topVendor,
        icon: Icons.emoji_events_rounded,
        tint: _C.amber,
        softBg: _C.amberSoft,
      ),
      _StatData(
        title: 'Pending Payment',
        value: '₹${_formatCurrency(_pendingPayment)}',
        icon: Icons.report_gmailerrorred_rounded,
        tint: _C.red,
        softBg: _C.redSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: w, child: _statCard(c)))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.softBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.divider),
      ),
      child: Row(
        children: [
          _tabChip(
            label: 'Vendors (${_totalVendors})',
            tab: VendorsTab.vendors,
          ),
          _tabChip(label: 'Purchases (0)', tab: VendorsTab.purchases),
          _tabChip(label: 'Payments (0)', tab: VendorsTab.payments),
        ],
      ),
    );
  }

  Widget _tabChip({required String label, required VendorsTab tab}) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _C.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Search vendors...',
          icon: Icon(Icons.search_rounded, size: 18, color: _C.textSecondary),
        ),
      ),
    );
  }

  Widget _vendorCard(VendorRecord vendor) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _C.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: _C.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: _C.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vendor.phone.isEmpty ? '—' : vendor.phone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _C.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.more_vert_rounded,
                    color: _C.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              if (vendor.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: _C.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vendor.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _C.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.storefront_rounded, color: _C.textSecondary, size: 30),
          SizedBox(height: 8),
          Text(
            'No vendors found yet',
            style: TextStyle(color: _C.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            color: _C.textSecondary,
            size: 28,
          ),
          SizedBox(height: 8),
          Text(
            'This section is coming soon',
            style: TextStyle(color: _C.textSecondary),
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
          const Icon(Icons.warning_amber_rounded, color: _C.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Failed to load vendors.',
              style: const TextStyle(fontSize: 13, color: _C.amber),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: const Text(
              'Retry',
              style: TextStyle(color: _C.amber, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

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

  String _formatCurrency(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }
}

class _AddVendorSheet extends StatefulWidget {
  const _AddVendorSheet({required this.repository});

  final VendorsRepository repository;

  @override
  State<_AddVendorSheet> createState() => _AddVendorSheetState();
}

class _AddVendorSheetState extends State<_AddVendorSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isActive = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _C.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Vendor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: _C.textSecondary,
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _fieldLabel('Vendor / Distributor Name', isRequired: true),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _nameCtrl,
                  hintText: 'e.g. Lays Distributor, PepsiCo Wholesale',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Phone'),
                          const SizedBox(height: 6),
                          _sheetField(
                            controller: _phoneCtrl,
                            hintText: '98765XXXXX',
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Email'),
                          const SizedBox(height: 6),
                          _sheetField(
                            controller: _emailCtrl,
                            hintText: 'vendor@email.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _fieldLabel('Address'),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _addressCtrl,
                  hintText: 'Vendor address',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _fieldLabel('Notes'),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _notesCtrl,
                  hintText: 'Any notes about this vendor...',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _C.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: _C.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Active vendor',
                          style: TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: _C.accent,
                        onChanged: (value) => setState(() {
                          _isActive = value;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _C.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                final name = _nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a vendor name.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _saving = true);
                                try {
                                  await widget.repository.createVendor(
                                    name: name,
                                    phone: _phoneCtrl.text,
                                    email: _emailCtrl.text,
                                    address: _addressCtrl.text,
                                    isActive: _isActive,
                                  );
                                  if (!mounted) return;
                                  Navigator.of(context).pop(true);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                  setState(() => _saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accentMid,
                          foregroundColor: _C.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Add Vendor',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: _C.accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _C.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accentMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accent),
        ),
      ),
    );
  }
}

class _RecordPurchaseSheet extends StatefulWidget {
  const _RecordPurchaseSheet({required this.repository, required this.vendors});

  final VendorsRepository repository;
  final List<VendorRecord> vendors;

  @override
  State<_RecordPurchaseSheet> createState() => _RecordPurchaseSheetState();
}

class _RecordPurchaseSheetState extends State<_RecordPurchaseSheet> {
  final TextEditingController _productCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _unitPriceCtrl = TextEditingController();
  final TextEditingController _totalCtrl = TextEditingController();
  final TextEditingController _amountPaidCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  VendorRecord? _selectedVendor;
  DateTime _purchaseDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _productCtrl.dispose();
    _qtyCtrl.dispose();
    _unitPriceCtrl.dispose();
    _totalCtrl.dispose();
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _C.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Record Purchase',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: _C.textSecondary,
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _fieldLabel('Vendor', isRequired: true),
                const SizedBox(height: 6),
                _vendorDropdown(),
                const SizedBox(height: 12),
                _fieldLabel('Product', isRequired: true),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _productCtrl,
                  hintText: 'e.g. Lays Classic (100g), Milk Packet',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Quantity', isRequired: true),
                          const SizedBox(height: 6),
                          _sheetField(
                            controller: _qtyCtrl,
                            hintText: '1',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _recalcTotal(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Unit Price (₹)', isRequired: true),
                          const SizedBox(height: 6),
                          _sheetField(
                            controller: _unitPriceCtrl,
                            hintText: 'Cost per unit',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _recalcTotal(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _fieldLabel('Total Amount (₹)', isRequired: true),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _totalCtrl,
                  hintText: 'Auto-calculated from Qty × Unit Price',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Auto-calculated from Qty × Unit Price. You can override it.',
                  style: TextStyle(fontSize: 11, color: _C.textSecondary),
                ),
                const SizedBox(height: 12),
                _fieldLabel('Amount Paying Now (₹)'),
                const SizedBox(height: 6),
                _sheetField(
                  controller: _amountPaidCtrl,
                  hintText: '0 = Unpaid',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Purchase Date'),
                          const SizedBox(height: 6),
                          _dateField(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Notes'),
                          const SizedBox(height: 6),
                          _sheetField(
                            controller: _notesCtrl,
                            hintText: 'Optional',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _C.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accentMid,
                          foregroundColor: _C.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Record Purchase',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vendorDropdown() {
    final items = widget.vendors;
    return DropdownButtonFormField<VendorRecord>(
      value: _selectedVendor,
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
          .toList(),
      onChanged: (value) => setState(() => _selectedVendor = value),
      decoration: InputDecoration(
        hintText: items.isEmpty ? 'No vendors available' : 'Select vendor',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accentMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accent),
        ),
      ),
    );
  }

  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.accentMid),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(_purchaseDate),
                style: const TextStyle(color: _C.textPrimary),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  void _recalcTotal() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final unit = double.tryParse(_unitPriceCtrl.text.trim()) ?? 0;
    final total = qty * unit;
    if (total > 0) {
      _totalCtrl.text = total.toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vendor.')));
      return;
    }
    final product = _productCtrl.text.trim();
    if (product.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name.')),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final unit = double.tryParse(_unitPriceCtrl.text.trim()) ?? 0;
    final total = double.tryParse(_totalCtrl.text.trim()) ?? (qty * unit);
    final paid = double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
    final paymentStatus = paid >= total
        ? 'paid'
        : paid > 0
        ? 'partial'
        : 'unpaid';

    if (qty <= 0 || unit <= 0 || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity and prices.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.createPurchase(
        vendorId: _selectedVendor!.id,
        productId: null,
        productName: product,
        quantity: qty,
        unitQuantity: 1,
        unitPrice: unit,
        totalAmount: total,
        paymentStatus: paymentStatus,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd-$mm-$yyyy';
  }

  Widget _fieldLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: _C.accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _C.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accentMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.accent),
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.softBg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final Color softBg;
}
