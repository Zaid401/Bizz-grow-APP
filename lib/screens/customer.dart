import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';
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

// ── Model (unchanged) ──────────────────────────────────────────────────────────
class CustomerRecord {
  const CustomerRecord({
    required this.name,
    required this.phone,
    this.address = '--',
    required this.tier,
    required this.orders,
    required this.totalSpent,
    required this.joinedAt,
  });

  final String name;
  final String phone;
  final String address;
  final String tier;
  final int orders;
  final double totalSpent;
  final DateTime joinedAt;
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final TextEditingController _search = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  StoreInfo? _storeInfo;
  bool _loading = true;
  String _filter = 'All';
  int _unreadNotifications = 0;
  final List<CustomerRecord> _all = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
    setState(() => _loading = true);
    try {
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() => _storeInfo = dash.storeInfo);
      await _loadUnreadNotifications();
      final customers = await _fetchCustomers();
      if (!mounted) return;
      setState(() {
        _all
          ..clear()
          ..addAll(customers);
      });
      _fadeController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<CustomerRecord>> _fetchCustomers() async {
    final rows = await _dashboardRepository.fetchCustomers();
    if (rows.isEmpty) return const [];
    return rows.map(_customerFromRow).toList();
  }

  CustomerRecord _customerFromRow(Map<String, dynamic> row) {
    final name = _str(row, [
      'customer_name',
      'name',
      'full_name',
      'fullName',
      'buyer_name',
    ], 'Customer');
    final phone = _str(row, [
      'phone',
      'phone_number',
      'customer_phone',
      'mobile',
      'mobile_number',
      'contact',
    ], '--');
    final address = _str(row, [
      'address',
      'customer_address',
      'shipping_address',
      'location',
      'city',
    ], '--');
    final tierRaw = _str(row, [
      'tier',
      'customer_tier',
      'segment',
      'customer_segment',
      'status',
      'type',
    ], 'Regular');
    final orders = _int(row, [
      'orders',
      'orders_count',
      'total_orders',
      'order_count',
    ]);
    final totalSpent = _dbl(row, [
      'total_spent',
      'lifetime_value',
      'total',
      'amount',
      'spent',
      'total_amount',
    ]);
    final joinedAt = _date(row, [
      'joined_at',
      'created_at',
      'createdAt',
      'registered_at',
      'signup_date',
    ]);
    return CustomerRecord(
      name: name,
      phone: phone,
      address: address,
      tier: _normalizeTier(tierRaw),
      orders: orders,
      totalSpent: totalSpent,
      joinedAt: joinedAt,
    );
  }

  String _str(Map<String, dynamic> r, List<String> keys, String fb) {
    for (final k in keys) {
      final v = r[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return fb;
  }

  int _int(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  double _dbl(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  DateTime _date(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is DateTime) return v;
      if (v is num) {
        final e = v.toInt();
        if (e > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(e);
        if (e > 1000000000)
          return DateTime.fromMillisecondsSinceEpoch(e * 1000);
      }
      if (v is String) {
        final raw = v.trim();
        final norm = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
        final parsed = DateTime.tryParse(norm) ?? DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return DateTime.now();
  }

  String _normalizeTier(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('vip')) return 'VIP';
    if (v.contains('new')) return 'New';
    if (v.contains('regular') || v.contains('standard')) return 'Regular';
    if (raw.trim().isEmpty) return 'Regular';
    return '${raw.trim()[0].toUpperCase()}${raw.trim().substring(1)}';
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
  List<CustomerRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((c) {
      final matchQ =
          q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q);
      final matchT = _filter == 'All' || c.tier == _filter;
      return matchQ && matchT;
    }).toList();
  }

  int get _totalCustomers => _all.length;
  int get _vipCustomers => _all.where((c) => c.tier == 'VIP').length;
  int get _newThisMonth {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = now.month == 12
        ? DateTime(now.year + 1)
        : DateTime(now.year, now.month + 1);
    return _all.where((c) {
      final j = c.joinedAt.toLocal();
      return !j.isBefore(start) && j.isBefore(end);
    }).length;
  }

  String get _avgLifetimeValue {
    if (_all.isEmpty) return '₹0';
    final total = _all.fold<double>(0, (s, c) => s + c.totalSpent);
    return '₹${(total / _all.length).toStringAsFixed(0)}';
  }

  // ── Add customer dialog ────────────────────────────────────────────────────
  Future<void> _openAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var tier = 'New';
    var saving = false;

    Future<void> handleSave(StateSetter setModal) async {
      final name = nameCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text('Name and phone are required.'),
              ],
            ),
            backgroundColor: _C.amber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      setModal(() => saving = true);
      try {
        await _insertCustomer(
          name: name,
          phone: phone,
          email: emailCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          tier: tier,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        await _load();
      } on PostgrestException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to add customer.')),
        );
      } finally {
        if (mounted) setModal(() => saving = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(dialogCtx).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_C.accentLight, _C.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: _C.accent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Customer',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _C.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(dialogCtx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: _C.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _dialogLabel('Full Name *'),
                    const SizedBox(height: 6),
                    _DialogField(
                      controller: nameCtrl,
                      hint: 'Enter customer name',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 14),

                    _dialogLabel('Phone Number *'),
                    const SizedBox(height: 6),
                    _DialogField(
                      controller: phoneCtrl,
                      hint: 'Enter phone number',
                      icon: Icons.phone_rounded,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    _dialogLabel('Email (Optional)'),
                    const SizedBox(height: 6),
                    _DialogField(
                      controller: emailCtrl,
                      hint: 'Enter email address',
                      icon: Icons.email_rounded,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    _dialogLabel('Address (Optional)'),
                    const SizedBox(height: 6),
                    _DialogField(
                      controller: addressCtrl,
                      hint: 'Enter address',
                      icon: Icons.location_on_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    _dialogLabel('Customer Tier'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _C.inputFill,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _C.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tier,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _C.textSecondary,
                          ),
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 14,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'New', child: Text('New')),
                            DropdownMenuItem(
                              value: 'Regular',
                              child: Text('Regular'),
                            ),
                            DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModal(() => tier = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: saving
                                ? null
                                : () => Navigator.of(dialogCtx).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: _C.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _C.divider),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _C.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: saving ? null : () => handleSave(setModal),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Add Customer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _C.textSecondary,
      letterSpacing: 0.2,
    ),
  );

  Future<void> _insertCustomer({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String tier,
  }) async {
    final storeId = await _dashboardRepository.resolveStoreId();
    if (storeId == null) throw StateError('Missing store id');
    await _client.from('customers').insert({
      'store_id': storeId,
      'name': name,
      'phone': phone,
      'email': email.isEmpty ? null : email,
      'address': address.isEmpty ? null : address,
      'status': tier,
      'total_orders': 0,
      'total_spent': 0,
    });
  }

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
        onOpenAiUpload: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.aiUpload,
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
        onOpenCustomers: () => Navigator.of(context).pop(),
        activeCustomers: true,
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
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
                      if (_loading)
                        _buildLoadingState()
                      else
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _filtered.isEmpty
                              ? _buildEmptyState()
                              : _CustomerList(customers: _filtered),
                        ),
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
            Icons.people_alt_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading
                    ? 'Loading customers…'
                    : 'Managing $_totalCustomers customers',
                style: const TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
        // Count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_totalCustomers total',
            style: const TextStyle(
              fontSize: 11,
              color: _C.accentLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Actions Row ────────────────────────────────────────────────────────────
  Widget _buildActionsRow() {
    return Row(
      children: [
        // Export
        GestureDetector(
          onTap: () {},
          child: Container(
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
        ),
        const SizedBox(width: 10),
        // Add Customer
        Expanded(
          child: GestureDetector(
            onTap: _openAddCustomerDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.accentLight, _C.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
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
                  Icon(Icons.person_add_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 8),
                  Text(
                    'Add Customer',
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
        '$_totalCustomers',
        Icons.people_alt_rounded,
        _C.accentLight,
        _C.accentSoft,
      ),
      _StatData(
        'VIP',
        '$_vipCustomers',
        Icons.workspace_premium_rounded,
        _C.amber,
        _C.amberSoft,
      ),
      _StatData(
        'New This Month',
        '$_newThisMonth',
        Icons.person_add_rounded,
        _C.green,
        _C.greenSoft,
      ),
      _StatData(
        'Avg Lifetime',
        _avgLifetimeValue,
        Icons.trending_up_rounded,
        _C.blue,
        _C.blueSoft,
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
          hintText: 'Search by name or phone…',
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
      _ChipData('All', _C.accentLight, _C.accentSoft),
      _ChipData('VIP', _C.amber, _C.amberSoft),
      _ChipData('Regular', _C.blue, _C.blueSoft),
      _ChipData('New', _C.green, _C.greenSoft),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          final active = _filter == c.label;
          return GestureDetector(
            onTap: () => setState(() => _filter = c.label),
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
            Icons.people_alt_rounded,
            size: 36,
            color: _C.accentLight,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No customers found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try a different filter or search term.',
          style: TextStyle(fontSize: 12, color: _C.textSecondary),
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
              onOpenVendors: () => ShellNav.switchTo(context, ShellTab.vendors),
              activeModule: MoreActionsModule.customers,
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
}

// ── Customer List (card-based, replaces horizontal-scroll table) ───────────────
class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.customers});
  final List<CustomerRecord> customers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: customers
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CustomerCard(customer: c),
            ),
          )
          .toList(),
    );
  }
}

void _showCustomerDetailsDialog(BuildContext context, CustomerRecord customer) {
  showDialog<void>(
    context: context,
    builder: (_) => _CustomerDetailsDialog(customer: customer),
  );
}

String _formatMonthYear(DateTime date) {
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
  final safeMonth = date.month.clamp(1, 12);
  return '${months[safeMonth - 1]} ${date.year}';
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    final tierStyle = _tierStyle(customer.tier);

    return GestureDetector(
      onTap: () => _showCustomerDetailsDialog(context, customer),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.accentSoft, _C.accentMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.accentMid),
                ),
                child: Center(
                  child: Text(
                    _initials(customer.name),
                    style: const TextStyle(
                      color: _C.accentLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _C.textPrimary,
                            ),
                          ),
                        ),
                        _TierBadge(tier: customer.tier, style: tierStyle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 12,
                          color: _C.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MetaPill(
                          Icons.shopping_bag_rounded,
                          '${customer.orders} orders',
                          _C.accentLight,
                          _C.accentSoft,
                        ),
                        const SizedBox(width: 8),
                        _MetaPill(
                          Icons.currency_rupee_rounded,
                          '₹${customer.totalSpent.toStringAsFixed(0)}',
                          _C.green,
                          _C.greenSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action buttons column
              Column(
                children: [
                  _ActionBtn(icon: Icons.chat_rounded, onTap: () {}),
                  const SizedBox(height: 8),
                  _ActionBtn(icon: Icons.phone_rounded, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailsDialog extends StatelessWidget {
  const _CustomerDetailsDialog({required this.customer});
  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    final tierStyle = _tierStyle(customer.tier);
    final joined = _formatMonthYear(customer.joinedAt.toLocal());

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: _C.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Customer Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: _C.textSecondary,
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.accentSoft, _C.accentMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.accentMid),
                  ),
                  child: Center(
                    child: Text(
                      _initials(customer.name),
                      style: const TextStyle(
                        color: _C.accentLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _C.textPrimary,
                              ),
                            ),
                          ),
                          _TierBadge(tier: customer.tier, style: tierStyle),
                        ],
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
                          Text(
                            customer.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.textSecondary,
                            ),
                          ),
                        ],
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
                  child: _CustomerStatCard(
                    label: 'Orders',
                    value: '${customer.orders}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CustomerStatCard(
                    label: 'Total Spent',
                    value: '₹${customer.totalSpent.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CustomerDetailRow(
              icon: Icons.event_rounded,
              label: 'Customer since',
              value: joined,
            ),
            const SizedBox(height: 6),
            _CustomerDetailRow(
              icon: Icons.star_rounded,
              label: 'Tier',
              value: customer.tier,
            ),
            const SizedBox(height: 6),
            _CustomerDetailRow(
              icon: Icons.place_rounded,
              label: 'Address',
              value: customer.address,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.green,
                      side: BorderSide(color: _C.green.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.textPrimary,
                      side: BorderSide(color: _C.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerStatCard extends StatelessWidget {
  const _CustomerStatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: _C.inputFill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.divider),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _C.textSecondary),
        ),
      ],
    ),
  );
}

class _CustomerDetailRow extends StatelessWidget {
  const _CustomerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: _C.textSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: _C.textSecondary),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          color: _C.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ── Tier Badge ─────────────────────────────────────────────────────────────────
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, required this.style});
  final String tier;
  final _TierStyle style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: style.bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: style.color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, size: 11, color: style.color),
        const SizedBox(width: 4),
        Text(
          tier,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: style.color,
          ),
        ),
      ],
    ),
  );
}

// ── Meta Pill ──────────────────────────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  const _MetaPill(this.icon, this.label, this.tint, this.bg);
  final IconData icon;
  final String label;
  final Color tint, bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: tint),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tint,
          ),
        ),
      ],
    ),
  );
}

// ── Action Button ──────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.divider),
      ),
      child: Icon(icon, size: 16, color: _C.textSecondary),
    ),
  );
}

// ── Dialog Field ───────────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboard,
    maxLines: maxLines,
    style: const TextStyle(color: _C.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _C.textSecondary.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: _C.textSecondary, size: 18),
      filled: true,
      fillColor: _C.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.accentLight, width: 1.5),
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
  const _ChipData(this.label, this.color, this.bg);
  final String label;
  final Color color, bg;
}

class _TierStyle {
  const _TierStyle(this.color, this.bg, this.icon);
  final Color color, bg;
  final IconData icon;
}

_TierStyle _tierStyle(String tier) {
  switch (tier) {
    case 'VIP':
      return const _TierStyle(
        _C.amber,
        _C.amberSoft,
        Icons.workspace_premium_rounded,
      );
    case 'New':
      return const _TierStyle(_C.green, _C.greenSoft, Icons.fiber_new_rounded);
    case 'Regular':
      return const _TierStyle(_C.blue, _C.blueSoft, Icons.person_rounded);
    default:
      return const _TierStyle(_C.textSecondary, _C.bg, Icons.person_rounded);
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
