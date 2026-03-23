import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'posBilling.dart';
import 'slider.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'notifications.dart';
import 'AI_upload.dart';
import '../services/products_repository.dart';
import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

final String _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
const int _lowStockThreshold = 5;

// ── Shared Palette ─────────────────────────────────────────────────────────────
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
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFDBEAFE);
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _search = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStock = 'All Stock';
  bool _listView = true;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;
  StoreInfo? _storeInfo;

  final ProductsRepository _repository = ProductsRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final SupabaseClient _client = Supabase.instance.client;
  List<ProductItem> _products = const [];

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
    _search.dispose();
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
      final items = await _repository.fetchProducts();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _products = items;
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<String> get _categories {
    final cats =
        _products
            .map((p) => p.categoryTag.isNotEmpty ? p.categoryTag : p.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...cats];
  }

  int get _total => _products.length;
  int get _inStock => _products.where((p) => !p.isOutOfStock).length;
  int get _lowStock => _products.where((p) => p.isLowStock).length;
  int get _outOfStock => _products.where((p) => p.isOutOfStock).length;

  List<ProductItem> get _filteredProducts {
    final q = _search.text.trim().toLowerCase();
    return _products.where((p) {
      final matchQ =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      final matchCat =
          _selectedCategory == 'All' ||
          p.categoryTag.toLowerCase() == _selectedCategory.toLowerCase() ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchStock = switch (_selectedStock) {
        'All Stock' => true,
        'In Stock' => !p.isOutOfStock,
        'Low Stock' => p.isLowStock,
        'Out of Stock' => p.isOutOfStock,
        _ => true,
      };
      return matchQ && matchCat && matchStock;
    }).toList();
  }

  Future<void> _updateStock(ProductItem product, int delta) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    final newStock = (product.stock + delta).clamp(0, 99999);
    final isOut = newStock <= 0;
    final isLow = newStock > 0 && newStock <= _lowStockThreshold;
    final updated = ProductItem(
      id: product.id,
      name: product.name,
      category: product.category,
      price: product.price,
      comparePrice: product.comparePrice,
      stock: newStock,
      description: product.description,
      imageUrl: product.imageUrl,
      status: isOut ? 'out_of_stock' : product.status,
      categoryTag: product.categoryTag,
      isAvailable: product.isAvailable,
      isLowStock: isLow,
      isOutOfStock: isOut,
    );
    setState(() {
      final list = [..._products];
      list[index] = updated;
      _products = list;
    });
    try {
      await _repository.updateStock(productId: product.id, stock: newStock);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final list = [..._products];
        list[index] = product;
        _products = list;
        _error = 'Stock update failed.';
      });
    }
  }

  void _applyProductUpdate(ProductItem updated) {
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;
    setState(() {
      final list = [..._products];
      list[index] = updated;
      _products = list;
    });
  }

  Future<void> _deleteProduct(ProductItem product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This will permanently delete "${product.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    final previous = [..._products];
    setState(() {
      final list = [..._products]..removeAt(index);
      _products = list;
    });
    try {
      await _repository.deleteProduct(productId: product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = previous;
        _error = 'Delete failed: $e';
      });
    }
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
        onOpenProducts: () => Navigator.of(context).pop(),
        activeProducts: true,
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
                    // AI banner
                    _AIBanner(onTap: _openAiUpload),
                    const SizedBox(height: 20),
                    // Page title
                    _buildTitleRow(),
                    const SizedBox(height: 16),
                    // Action buttons
                    _buildActionsRow(),
                    const SizedBox(height: 16),
                    // Stats grid
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    // Search
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    // Category chips
                    _buildCategoryChips(),
                    const SizedBox(height: 12),
                    // Stock filters + view toggle
                    _buildStockAndToggleRow(),
                    const SizedBox(height: 16),
                    // Content
                    if (_error != null)
                      _buildErrorBanner()
                    else if (_loading)
                      _buildLoadingState()
                    else if (_filteredProducts.isEmpty)
                      _buildEmptyState()
                    else
                      FadeTransition(
                        opacity:
                            _fadeAnimation ?? const AlwaysStoppedAnimation(1),
                        child: _listView
                            ? _ProductTable(
                                products: _filteredProducts,
                                onIncrease: (p) => _updateStock(p, 1),
                                onDecrease: (p) => _updateStock(p, -1),
                                onUpdated: _applyProductUpdate,
                                onDelete: _deleteProduct,
                              )
                            : _ProductGrid(
                                products: _filteredProducts,
                                onUpdated: _applyProductUpdate,
                                onDelete: _deleteProduct,
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
            Icons.inventory_2_rounded,
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
                'Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading ? 'Loading products…' : 'Managing $_total products',
                style: const TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
        ),
        // Product count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_total items',
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
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _OutlineBtn(
          icon: Icons.upload_file_rounded,
          label: 'CSV Import',
          onTap: () {},
        ),
        _OutlineBtn(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Upload',
          onTap: _openAiUpload,
        ),
        _PrimaryBtn(
          icon: Icons.add_rounded,
          label: 'Add Product',
          onTap: () => _showAddSheet(context),
        ),
      ],
    );
  }

  // ── Stats Grid ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final items = [
      _StatData(
        'Total',
        '$_total',
        Icons.all_inbox_rounded,
        _C.accentLight,
        _C.accentSoft,
      ),
      _StatData(
        'In Stock',
        '$_inStock',
        Icons.check_circle_rounded,
        _C.green,
        _C.greenSoft,
      ),
      _StatData(
        'Low Stock',
        '$_lowStock',
        Icons.warning_amber_rounded,
        _C.amber,
        _C.amberSoft,
      ),
      _StatData(
        'Out of Stock',
        '$_outOfStock',
        Icons.cancel_rounded,
        _C.red,
        _C.redSoft,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (_, i) {
        final d = items[i];
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _C.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _C.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          hintText: 'Search products by name or category…',
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

  // ── Category Chips ─────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final active = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? _C.accent : _C.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _C.accent : _C.divider),
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
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _C.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Stock Filters + View Toggle ────────────────────────────────────────────
  Widget _buildStockAndToggleRow() {
    final filters = [
      _StockChip('All Stock', _C.accentLight, _C.accentSoft),
      _StockChip('In Stock', _C.green, _C.greenSoft),
      _StockChip('Low Stock', _C.amber, _C.amberSoft),
      _StockChip('Out of Stock', _C.red, _C.redSoft),
    ];
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = filters[i];
                final active = _selectedStock == f.label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStock = f.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? f.bg : _C.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? f.color.withOpacity(0.4) : _C.divider,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? f.color : _C.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        // View toggle
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.divider),
          ),
          child: Row(
            children: [
              _ViewBtn(
                icon: Icons.grid_view_rounded,
                active: !_listView,
                onTap: () => setState(() => _listView = false),
              ),
              _ViewBtn(
                icon: Icons.format_list_bulleted_rounded,
                active: _listView,
                onTap: () => setState(() => _listView = true),
              ),
            ],
          ),
        ),
      ],
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
            Icons.inventory_2_rounded,
            size: 36,
            color: _C.accentLight,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No products found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try adjusting search, category, or stock filters.',
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
        currentIndex: 2,
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
              activeModule: MoreActionsModule.products,
              onAddProduct: () => _showAddSheet(context),
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

  void _showAddSheet(BuildContext context) {
    final cats = _categories.where((c) => c != 'All').toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductSheet(categories: cats),
    );
  }

  void _openAiUpload() {
    ShellNav.switchTo(
      context,
      ShellTab.aiUpload,
      fallback: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AiUploadScreen())),
    );
  }
}

// ── AI Banner ──────────────────────────────────────────────────────────────────
class _AIBanner extends StatelessWidget {
  const _AIBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.accent.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '10x Faster',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Auto Enhance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Try AI Product Upload',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Snap a photo → AI extracts details → Done!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: _C.accentLight, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Try AI Upload',
                        style: TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
    );
  }
}

// ── Outline + Primary buttons ──────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _C.textSecondary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ViewBtn extends StatelessWidget {
  const _ViewBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: active ? _C.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 18,
        color: active ? Colors.white : _C.textSecondary,
      ),
    ),
  );
}

// ── Product Table (list view) ──────────────────────────────────────────────────
class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.onIncrease,
    required this.onDecrease,
    required this.onUpdated,
    required this.onDelete,
  });
  final List<ProductItem> products;
  final ValueChanged<ProductItem> onIncrease;
  final ValueChanged<ProductItem> onDecrease;
  final ValueChanged<ProductItem> onUpdated;
  final Future<void> Function(ProductItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final compact = constraints.maxWidth < 520;
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
              if (!compact) _buildTableHeader(),
              ...products.map(
                (p) => _ProductRow(
                  product: p,
                  compact: compact,
                  onIncrease: () => onIncrease(p),
                  onDecrease: () => onDecrease(p),
                  onUpdated: onUpdated,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
        border: const Border(bottom: BorderSide(color: _C.divider)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 4, child: _HeaderCell('Product')),
          Expanded(flex: 3, child: _HeaderCell('Category')),
          Expanded(flex: 2, child: _HeaderCell('Price')),
          Expanded(flex: 2, child: _HeaderCell('Stock')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: _C.textSecondary,
      letterSpacing: 0.3,
    ),
  );
}

// ── Product Row ────────────────────────────────────────────────────────────────
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.compact,
    required this.onIncrease,
    required this.onDecrease,
    required this.onUpdated,
    required this.onDelete,
  });
  final ProductItem product;
  final bool compact;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<ProductItem> onUpdated;
  final Future<void> Function(ProductItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final badge = _stockBadge(product);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.divider, width: 0.8)),
      ),
      child: compact
          ? _compactLayout(context, badge)
          : _fullLayout(context, badge),
    );
  }

  Widget _compactLayout(BuildContext context, _BadgeData badge) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _ProductThumb(url: product.imageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                _StatusBadge(
                  label: badge.label,
                  color: badge.color,
                  softBg: badge.softBg,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildMenu(context),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              product.category,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '₹${product.price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          _QtyBtn(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
            isRemove: product.stock <= 0,
          ),
          const SizedBox(width: 10),
          Text(
            '${product.stock}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 10),
          _QtyBtn(icon: Icons.add_rounded, onTap: onIncrease),
        ],
      ),
    ],
  );

  Widget _fullLayout(BuildContext context, _BadgeData badge) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        flex: 4,
        child: Row(
          children: [
            _ProductThumb(url: product.imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _StatusBadge(
                    label: badge.label,
                    color: badge.color,
                    softBg: badge.softBg,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          product.category,
          style: const TextStyle(
            color: _C.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(
          '₹${product.price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
      ),
      Expanded(
        flex: 2,
        child: Row(
          children: [
            _QtyBtn(
              icon: Icons.remove_rounded,
              onTap: onDecrease,
              isRemove: product.stock <= 0,
            ),
            const SizedBox(width: 8),
            Text(
              '${product.stock}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            _QtyBtn(icon: Icons.add_rounded, onTap: onIncrease),
          ],
        ),
      ),
      const SizedBox(width: 6),
      _buildMenu(context),
    ],
  );

  Widget _buildMenu(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      shape: BoxShape.circle,
      border: Border.all(color: _C.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: PopupMenuButton<String>(
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: _C.textSecondary,
      ),
      onSelected: (value) {
        _handleProductMenuAction(context, product, value, onUpdated, onDelete);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'View', child: Text('View')),
        PopupMenuItem(value: 'Edit', child: Text('Edit')),
        PopupMenuItem(value: 'Create Flyers', child: Text('Create Flyers')),
        PopupMenuItem(value: 'Delete', child: Text('Delete')),
      ],
    ),
  );
}

// ── Product Grid ───────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.onUpdated,
    required this.onDelete,
  });
  final List<ProductItem> products;
  final ValueChanged<ProductItem> onUpdated;
  final Future<void> Function(ProductItem) onDelete;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: products.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 260,
    ),
    itemBuilder: (_, i) => _ProductCard(
      product: products[i],
      onUpdated: onUpdated,
      onDelete: onDelete,
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onUpdated,
    required this.onDelete,
  });
  final ProductItem product;
  final ValueChanged<ProductItem> onUpdated;
  final Future<void> Function(ProductItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final badge = _stockBadge(product);
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  color: _C.accentSoft,
                  child: product.imageUrl.isEmpty
                      ? const Icon(
                          Icons.inventory_2_rounded,
                          color: _C.accentLight,
                          size: 36,
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: _C.accentLight,
                            size: 36,
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      tooltip: 'More actions',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: _C.textSecondary,
                      ),
                      onSelected: (value) {
                        _handleProductMenuAction(
                          context,
                          product,
                          value,
                          onUpdated,
                          onDelete,
                        );
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'View', child: Text('View')),
                        PopupMenuItem(value: 'Edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'Create Flyers',
                          child: Text('Create Flyers'),
                        ),
                        PopupMenuItem(value: 'Delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.category,
                    style: const TextStyle(
                      color: _C.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _C.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        label: badge.label,
                        color: badge.color,
                        softBg: badge.softBg,
                      ),
                    ],
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

// ── Add Product Sheet ──────────────────────────────────────────────────────────
class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet({required this.categories});
  final List<String> categories;

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _comparePriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  File? _selectedImage;
  bool _availableForSale = true;
  bool _submitting = false;
  String? _error;
  String _category = 'Select category';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _comparePriceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() => _selectedImage = File(img.path));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    if (name.isEmpty || price.isEmpty) {
      setState(() => _error = 'Product name and price are required.');
      return;
    }
    if (_selectedImage == null) {
      setState(() => _error = 'Please add a product image.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final storeId = await _resolveStoreId();
      final imageUrl = await _uploadImage(_selectedImage!);
      final response = await http.post(
        Uri.parse('https://zyaawadtgdvawkdmnkcz.supabase.co/rest/v1/products'),
        headers: _restHeaders,
        body: jsonEncode({
          if (storeId != null) 'store_id': storeId,
          'name': name,
          'description': _descCtrl.text.trim(),
          'price': double.tryParse(price) ?? 0,
          'compare_price': double.tryParse(_comparePriceCtrl.text.trim()) ?? 0,
          'category': _category == 'Select category' ? '' : _category,
          'image_url': imageUrl,
          'is_available': _availableForSale,
          'stock_quantity': int.tryParse(_stockCtrl.text.trim()) ?? 0,
        }),
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() => _error = 'Upload failed. ${response.body}');
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, String> get _restHeaders => {
    'apikey': _supabaseAnonKey,
    'Authorization': 'Bearer $_supabaseAnonKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  Future<String?> _resolveStoreId() async {
    final user = _supabase.auth.currentUser;
    final meta = user?.userMetadata?['store_id']?.toString();
    if (meta != null && meta.isNotEmpty) return meta;
    if (user == null) return null;
    final stores = await _supabase
        .from('stores')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);
    if (stores is List && stores.isNotEmpty)
      return (stores.first as Map)['id']?.toString();
    return null;
  }

  Future<String> _uploadImage(File f) async {
    const bucket = 'product-images';
    final ext = f.path.split('.').last;
    final name = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final objPath = 'products/$name';
    final uri = Uri.parse(
      'https://zyaawadtgdvawkdmnkcz.supabase.co/storage/v1/object/$bucket/$objPath',
    );
    final res = await http.put(
      uri,
      headers: {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': _mime(ext),
        'x-upsert': 'true',
      },
      body: await f.readAsBytes(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300)
      throw Exception('Image upload failed: ${res.body}');
    return 'https://zyaawadtgdvawkdmnkcz.supabase.co/storage/v1/object/public/$bucket/$objPath';
  }

  String _mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final categories = ['Select category', ...widget.categories];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + bottomPad),
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.accentLight, _C.accent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_box_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Add New Product',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _C.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
              const SizedBox(height: 18),

              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.accentMid, width: 1.5),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _C.surface.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 30,
                                color: _C.accentLight,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tap to upload product image',
                              style: TextStyle(
                                color: _C.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),

              // Fields
              _sheetLabel('Product Name *'),
              const SizedBox(height: 6),
              _SheetField(controller: _nameCtrl, hint: 'Enter product name'),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('Price (₹) *'),
                        const SizedBox(height: 6),
                        _SheetField(
                          controller: _priceCtrl,
                          hint: '0',
                          keyboard: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('Compare Price'),
                        const SizedBox(height: 6),
                        _SheetField(
                          controller: _comparePriceCtrl,
                          hint: '0',
                          keyboard: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('Category'),
                        const SizedBox(height: 6),
                        _SheetDropdown(
                          value: _category,
                          items: categories,
                          onChanged: (v) =>
                              setState(() => _category = v ?? _category),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('Stock Quantity'),
                        const SizedBox(height: 6),
                        _SheetField(
                          controller: _stockCtrl,
                          hint: '0',
                          keyboard: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _sheetLabel('Description'),
              const SizedBox(height: 6),
              _SheetField(
                controller: _descCtrl,
                hint: 'Enter product description…',
                maxLines: 4,
              ),
              const SizedBox(height: 14),

              // Available toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: _C.accentLight,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Available for sale',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _availableForSale,
                      activeColor: _C.accentLight,
                      onChanged: (v) => setState(() => _availableForSale = v),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.redSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: _C.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: _C.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onTap: _submitting ? null : _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Add Product',
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
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _C.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}

// ── Sheet Field + Dropdown ─────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
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

class _SheetDropdown extends StatelessWidget {
  const _SheetDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: _C.inputFill,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _C.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _C.textSecondary,
        ),
        style: const TextStyle(color: _C.textPrimary, fontSize: 14),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Shared small widgets ───────────────────────────────────────────────────────
class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(11),
    child: Container(
      width: 46,
      height: 46,
      color: _C.accentSoft,
      child: url.isEmpty
          ? const Icon(
              Icons.inventory_2_rounded,
              color: _C.accentLight,
              size: 22,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                color: _C.accentLight,
                size: 22,
              ),
            ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.softBg,
  });
  final String label;
  final Color color, softBg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: softBg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
    required this.icon,
    required this.onTap,
    this.isRemove = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool isRemove;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isRemove ? _C.redSoft : _C.accentSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isRemove ? _C.red.withOpacity(0.2) : _C.accentMid,
        ),
      ),
      child: Icon(icon, size: 16, color: isRemove ? _C.red : _C.accentLight),
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

class _StockChip {
  const _StockChip(this.label, this.color, this.bg);
  final String label;
  final Color color, bg;
}

class _BadgeData {
  const _BadgeData(this.label, this.color, this.softBg);
  final String label;
  final Color color, softBg;
}

void _handleProductMenuAction(
  BuildContext context,
  ProductItem product,
  String value,
  ValueChanged<ProductItem> onUpdated,
  Future<void> Function(ProductItem) onDelete,
) {
  switch (value) {
    case 'View':
      _showProductDetailsDialog(context, product, onUpdated);
      return;
    case 'Edit':
      _showEditProductDialog(context, product, onUpdated);
      return;
    case 'Create Flyers':
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create Flyers tapped')));
      return;
    case 'Delete':
      onDelete(product);
      return;
    default:
      return;
  }
}

void _showProductDetailsDialog(
  BuildContext context,
  ProductItem product,
  ValueChanged<ProductItem> onUpdated,
) {
  final category = product.categoryTag.isNotEmpty
      ? product.categoryTag
      : product.category;
  final isActive = product.isAvailable;
  final inStock = !product.isOutOfStock && product.stock > 0 && isActive;
  final availabilityText = inStock ? 'Available for sale' : 'Out of stock';
  final availabilityColor = inStock ? _C.green : _C.red;

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final image = ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 120,
                  height: 120,
                  color: _C.accentSoft,
                  child: product.imageUrl.isEmpty
                      ? const Icon(
                          Icons.inventory_2_rounded,
                          color: _C.accentLight,
                          size: 44,
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: _C.accentLight,
                            size: 44,
                          ),
                        ),
                ),
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: inStock ? _C.greenSoft : _C.redSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'active' : 'inactive',
                      style: TextStyle(
                        color: isActive ? _C.green : _C.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Price',
                    style: TextStyle(fontSize: 12, color: _C.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 12,
                                color: _C.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.isEmpty ? '-' : category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _C.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stock Quantity',
                              style: TextStyle(
                                fontSize: 12,
                                color: _C.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.stock} units',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _C.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Availability',
                    style: TextStyle(fontSize: 12, color: _C.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: availabilityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        availabilityText,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: availabilityColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 12, color: _C.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description.isEmpty
                        ? 'Description not available.'
                        : product.description,
                    style: const TextStyle(color: _C.textPrimary, fontSize: 13),
                  ),
                ],
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: _C.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isNarrow) ...[
                    Center(child: image),
                    const SizedBox(height: 16),
                    details,
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image,
                        const SizedBox(width: 18),
                        Expanded(child: details),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showEditProductDialog(context, product, onUpdated);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit Product'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.accent,
                            side: const BorderSide(color: _C.accent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Create Flyer')),
                            );
                          },
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: const Text('Create Flyer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: _C.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: _C.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _showEditProductDialog(
  BuildContext context,
  ProductItem product,
  ValueChanged<ProductItem> onUpdated,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _EditProductDialog(
      product: product,
      parentContext: context,
      onUpdated: onUpdated,
    ),
  );
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({
    required this.product,
    required this.parentContext,
    required this.onUpdated,
  });

  final ProductItem product;
  final BuildContext parentContext;
  final ValueChanged<ProductItem> onUpdated;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _comparePriceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descCtrl;
  final ProductsRepository _repository = ProductsRepository();

  bool _isAvailable = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameCtrl = TextEditingController(text: product.name);
    _priceCtrl = TextEditingController(
      text: product.price == 0 ? '' : product.price.toStringAsFixed(0),
    );
    _comparePriceCtrl = TextEditingController(
      text: product.comparePrice == 0
          ? ''
          : product.comparePrice.toStringAsFixed(0),
    );
    _categoryCtrl = TextEditingController(text: product.category);
    _stockCtrl = TextEditingController(
      text: product.stock == 0 ? '' : product.stock.toString(),
    );
    _descCtrl = TextEditingController(text: product.description);
    _isAvailable = product.isAvailable;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _comparePriceCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final priceRaw = _priceCtrl.text.trim();
    if (name.isEmpty || priceRaw.isEmpty) {
      setState(() => _error = 'Product name and price are required.');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      final category = _categoryCtrl.text.trim();
      final price = double.tryParse(priceRaw) ?? 0;
      final comparePrice = double.tryParse(_comparePriceCtrl.text.trim()) ?? 0;
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
      final isOut = stock <= 0;
      final isLow = stock > 0 && stock <= _lowStockThreshold;
      await _repository.updateProduct(
        productId: widget.product.id,
        name: name,
        category: category,
        price: price,
        comparePrice: comparePrice,
        stock: stock,
        description: _descCtrl.text.trim(),
        isAvailable: _isAvailable,
      );
      if (!mounted) return;
      final updated = ProductItem(
        id: widget.product.id,
        name: name,
        category: category,
        price: price,
        comparePrice: comparePrice,
        stock: stock,
        description: _descCtrl.text.trim(),
        imageUrl: widget.product.imageUrl,
        status: isOut ? 'out_of_stock' : widget.product.status,
        categoryTag: widget.product.categoryTag,
        isAvailable: _isAvailable,
        isLowStock: isLow,
        isOutOfStock: isOut,
      );
      widget.onUpdated(updated);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('Product updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Update failed: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: _C.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Product Name *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _C.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                _SheetField(controller: _nameCtrl, hint: 'Enter product name'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price (₹) *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SheetField(
                            controller: _priceCtrl,
                            hint: '0',
                            keyboard: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compare Price',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SheetField(
                            controller: _comparePriceCtrl,
                            hint: '0',
                            keyboard: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SheetField(
                            controller: _categoryCtrl,
                            hint: 'Category',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock Quantity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SheetField(
                            controller: _stockCtrl,
                            hint: '0',
                            keyboard: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _C.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                _SheetField(
                  controller: _descCtrl,
                  hint: 'Enter product description…',
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: _C.accentLight,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Available for sale',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _isAvailable,
                        activeColor: _C.accentLight,
                        onChanged: (value) =>
                            setState(() => _isAvailable = value),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.redSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _C.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: _C.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                        onTap: _isSubmitting ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
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
        ),
      ),
    );
  }
}

_BadgeData _stockBadge(ProductItem p) {
  if (p.isOutOfStock)
    return const _BadgeData('Out of Stock', _C.red, _C.redSoft);
  if (p.isLowStock)
    return const _BadgeData('Low Stock', _C.amber, _C.amberSoft);
  return const _BadgeData('In Stock', _C.green, _C.greenSoft);
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
