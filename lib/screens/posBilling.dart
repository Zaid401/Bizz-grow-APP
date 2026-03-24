import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'slider.dart';
import 'orders.dart';
import 'products.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'delivery.dart';
import 'store_settings.dart';
import 'dashboard.dart';
import 'notifications.dart';
import '../services/dashboard_repository.dart';
import '../services/pos_repository.dart';
import '../services/pos_due_payments.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final PosRepository _repository = PosRepository();
  final TextEditingController _search = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  List<PosProduct> _products = const [];
  StoreInfo? _storeInfo;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;

  static const Color _navSurface = Color(0xFFFFFFFF);
  static const Color _navDivider = Color(0xFFE9E2F6);
  static const Color _navAccent = Color(0xFF5B21B6);
  static const Color _navText = Color(0xFF6B5E85);

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final products = await _repository.fetchProducts();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _products = products;
        _storeInfo = dash.storeInfo;
      });
      await _loadUnreadNotifications();
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

  List<PosProduct> get _filteredProducts {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4D0E7F);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: DashboardDrawer(
        store: _storeInfo,
        onClose: () => Navigator.of(context).pop(),
        onOpenPosBilling: () => Navigator.of(context).pop(),
        onOpenDashboard: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.dashboard,
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
        onOpenVendors: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.vendors,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenAiUpload: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.aiUpload,
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
        activePosBilling: true,
      ),
      bottomNavigationBar: _buildBottomNav(),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TitleBar(
                      onOpenDuePayments: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PosDuePaymentsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _SearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null)
                      _ErrorBanner(message: _error!, onRetry: _load)
                    else if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_filteredProducts.isEmpty)
                      const _EmptyProducts()
                    else
                      _ProductList(products: _filteredProducts),
                    const SizedBox(height: 18),
                    const _CartCard(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _navSurface,
        border: Border(top: BorderSide(color: _navDivider)),
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
        selectedItemColor: _navAccent,
        unselectedItemColor: _navText,
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
              activeModule: MoreActionsModule.posBilling,
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

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onOpenDuePayments});

  final VoidCallback onOpenDuePayments;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.point_of_sale, color: Color(0xFF4D0E7F)),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POS Billing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF241132),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Quick billing for walk-in customers',
                style: TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onOpenDuePayments,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF4D0E7F), width: 1.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.payments_outlined, color: Color(0xFF4D0E7F)),
          label: const Text(
            'Due Payments',
            style: TextStyle(
              color: Color(0xFF4D0E7F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        hintText: 'Search products by name or category...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF4A3A59)),
        filled: true,
        fillColor: const Color(0xFFF7F5FB),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
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

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products});

  final List<PosProduct> products;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = products[index];
        return _ProductCard(product: p);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              color: const Color(0xFFF4EEF9),
              child: product.imageUrl.isEmpty
                  ? const Icon(Icons.photo_outlined, color: Color(0xFF9A8FA5))
                  : Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF9A8FA5),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C1937),
                  ),
                ),
                const SizedBox(height: 6),
                if (product.category.isNotEmpty)
                  Text(
                    product.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F758B),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '₹${_formatPrice(product.price)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4D0E7F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4D0E7F)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                color: Color(0xFF4D0E7F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartCard extends StatelessWidget {
  const _CartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cart (0)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: const [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 40,
                  color: Color(0xFFB2A9BD),
                ),
                SizedBox(height: 8),
                Text(
                  'Cart is empty',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
                ),
                SizedBox(height: 6),
                Text(
                  'Click products to add',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A8FA5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        children: const [
          Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFFB2A9BD)),
          SizedBox(height: 10),
          Text(
            'No products yet',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
          ),
          SizedBox(height: 6),
          Text(
            'Add items to see them here',
            style: TextStyle(fontSize: 13, color: Color(0xFF9A8FA5)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2C46D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF8B5E00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5C4200)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _formatPrice(double value) {
  if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'ST' : letters.toUpperCase();
}
