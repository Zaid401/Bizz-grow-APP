import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'posBilling.dart';
import 'slider.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'delivery.dart';
import '../services/products_repository.dart';
import '../services/dashboard_repository.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _search = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStock = 'All Stock';
  bool _listView = true;
  bool _loading = true;
  String? _error;
  StoreInfo? _storeInfo;
  final ProductsRepository _repository = ProductsRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  List<ProductItem> _products = const [];

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
      final items = await _repository.fetchProducts();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _products = items;
        _storeInfo = dash.storeInfo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      final matchesQuery = q.isEmpty
          ? true
          : p.name.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q);
      final matchesCategory = _selectedCategory == 'All'
          ? true
          : p.categoryTag.toLowerCase() == _selectedCategory.toLowerCase() ||
                p.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesStock = switch (_selectedStock) {
        'All Stock' => true,
        'In Stock' || 'In Stock (1)' => !p.isOutOfStock,
        'Low Stock' || 'Low Stock (0)' => p.isLowStock,
        'Out of Stock' => p.isOutOfStock,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesStock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4D0E7F);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: DashboardDrawer(
        onClose: () => Navigator.of(context).pop(),
        store: _storeInfo,
        onOpenDashboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        },
        onOpenPosBilling: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PosBillingScreen()));
        },
        onOpenOrders: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
        },
        onOpenCustomers: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CustomerScreen()));
        },
        onOpenAnalytics: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
        },
        onOpenDelivery: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DeliveryScreen()));
        },
        onOpenProducts: () => Navigator.of(context).pop(),
        activeProducts: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF8B7F95),
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else if (index == 1) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
          } else if (index == 2) {
            // stay
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(accent: accent, store: _storeInfo),
                const SizedBox(height: 10),
                _Banner(accent: accent),
                const SizedBox(height: 18),
                _ProductsHeader(
                  accent: accent,
                  total: _total,
                  loading: _loading,
                ),
                const SizedBox(height: 12),
                _ActionsRow(accent: accent),
                const SizedBox(height: 16),
                _StatsGrid(
                  accent: accent,
                  total: _total,
                  active: _inStock,
                  low: _lowStock,
                  out: _outOfStock,
                ),
                const SizedBox(height: 16),
                _SearchBar(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _CategoryChips(
                  categories: _categories,
                  selected: _selectedCategory,
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 12),
                _ViewToggles(
                  listView: _listView,
                  onChanged: (isList) => setState(() => _listView = isList),
                ),
                const SizedBox(height: 12),
                _StockFilters(
                  selected: _selectedStock,
                  onChanged: (value) => setState(() => _selectedStock = value),
                  inStock: _inStock,
                  lowStock: _lowStock,
                  outOfStock: _outOfStock,
                ),
                const SizedBox(height: 12),
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
                  const _EmptyState()
                else if (_listView)
                  _ProductTable(products: _filteredProducts)
                else
                  _ProductGrid(products: _filteredProducts),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.accent, required this.store});

  final Color accent;
  final StoreInfo? store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF4A3A59)),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        const Spacer(),
        _BadgeIcon(
          icon: Icons.notifications_none_rounded,
          count: 1,
          accent: accent,
        ),
        const SizedBox(width: 6),
        _BadgeIcon(icon: Icons.headset_mic_outlined, count: 1, accent: accent),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: accent,
          child: Text(
            _initials(store?.name ?? 'Store'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    required this.accent,
  });

  final IconData icon;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF4EEF9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A3A59)),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF7A2DD1), Color(0xFF4D0E7F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _Chip(label: '10x Faster', icon: Icons.flash_on),
              _Chip(label: 'Auto Enhance', icon: Icons.auto_awesome),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Try AI Product Upload',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Snap a photo → AI extracts details → Done! The fastest way to add products.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {},
            icon: const Icon(Icons.flash_on),
            label: const Text(
              'Try AI Upload',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({
    required this.accent,
    required this.total,
    required this.loading,
  });

  final Color accent;
  final int total;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final subtitle = loading
        ? 'Loading products...'
        : 'Manage your product catalogue ($total products)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Products',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF241132),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF7F758B)),
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
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            side: const BorderSide(color: Color(0xFFE3DFEA), width: 1.2),
            foregroundColor: const Color(0xFF241132),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text(
            'CSV Import',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            side: const BorderSide(color: Color(0xFFE3DFEA), width: 1.2),
            foregroundColor: const Color(0xFF241132),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: const Text(
            'AI Upload',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text(
            'Add Product',
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
    required this.active,
    required this.low,
    required this.out,
  });

  final Color accent;
  final int total;
  final int active;
  final int low;
  final int out;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat(
        label: 'Total Products',
        value: '$total',
        icon: Icons.all_inbox_outlined,
        color: const Color(0xFF8C6BFF),
      ),
      _Stat(
        label: 'Active',
        value: '$active',
        icon: Icons.trending_up,
        color: const Color(0xFF3BB273),
      ),
      _Stat(
        label: 'Low Stock',
        value: '$low',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE18A00),
      ),
      _Stat(
        label: 'Out of Stock',
        value: '$out',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFDA3C3C),
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1DBEA)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1,
                        color: Color(0xFF4A3A59),
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
}

class _Stat {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search products...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF4A3A59)),
        filled: true,
        fillColor: const Color(0xFFF7F5FB),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3DFEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4D0E7F)),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(c),
                  selected: selected == c,
                  onSelected: (_) => onChanged(c),
                  selectedColor: const Color(0xFF4D0E7F),
                  backgroundColor: const Color(0xFFF7F5FB),
                  labelStyle: TextStyle(
                    color: selected == c
                        ? Colors.white
                        : const Color(0xFF4A3A59),
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ViewToggles extends StatelessWidget {
  const _ViewToggles({required this.listView, required this.onChanged});

  final bool listView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        ToggleButtons(
          isSelected: [!listView, listView],
          onPressed: (i) => onChanged(i == 1),
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          color: const Color(0xFF4A3A59),
          fillColor: const Color(0xFF4D0E7F),
          constraints: const BoxConstraints(minWidth: 46, minHeight: 40),
          children: const [
            Icon(Icons.grid_view_rounded),
            Icon(Icons.format_list_bulleted),
          ],
        ),
      ],
    );
  }
}

class _StockFilters extends StatelessWidget {
  const _StockFilters({
    required this.selected,
    required this.onChanged,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  @override
  Widget build(BuildContext context) {
    final filters = [
      _StockFilter(label: 'All Stock', color: const Color(0xFF4A3A59)),
      _StockFilter(
        label: 'In Stock ($inStock)',
        color: const Color(0xFF1AA567),
      ),
      _StockFilter(
        label: 'Low Stock ($lowStock)',
        color: const Color(0xFFE18A00),
      ),
      _StockFilter(label: 'Out of Stock', color: const Color(0xFFDA3C3C)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: selected == f.label,
                  onSelected: (_) => onChanged(f.label),
                  selectedColor: f.color.withOpacity(0.14),
                  backgroundColor: const Color(0xFFF7F5FB),
                  labelStyle: TextStyle(
                    color: f.color,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StockFilter {
  const _StockFilter({required this.label, required this.color});
  final String label;
  final Color color;
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products});

  final List<ProductItem> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              color: const Color(0xFFF7F5FB),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE3DFEA)),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Product',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A3A59),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A3A59),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A3A59),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A3A59),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...products.map((p) => _ProductRow(product: p)).toList(),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<ProductItem> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 255,
      ),
      itemBuilder: (_, i) => _ProductCard(product: products[i]),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final ProductItem product;

  @override
  Widget build(BuildContext context) {
    final badgeColor = product.isOutOfStock
        ? const Color(0xFFDA3C3C)
        : product.isLowStock
        ? const Color(0xFFE18A00)
        : const Color(0xFF1AA567);
    final badgeLabel = product.isOutOfStock
        ? 'Out'
        : product.isLowStock
        ? 'Low'
        : 'In Stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE3DFEA), width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: const Color(0xFFF4EEF9),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.photo, color: Color(0xFF9A8FA5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF241132),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
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
                color: Color(0xFF7F758B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF241132),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _QtyButton(icon: Icons.remove, onTap: () {}),
                const SizedBox(width: 8),
                Text(
                  product.stock.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241132),
                  ),
                ),
                const SizedBox(width: 8),
                _QtyButton(icon: Icons.add, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductItem product;

  @override
  Widget build(BuildContext context) {
    final badgeColor = product.isOutOfStock
        ? const Color(0xFFDA3C3C)
        : product.isLowStock
        ? const Color(0xFFE18A00)
        : const Color(0xFF1AA567);
    final badgeLabel = product.isOutOfStock
        ? 'Out of stock'
        : product.isLowStock
        ? 'Low stock'
        : 'In stock';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              width: double.infinity,
              color: const Color(0xFFF4EEF9),
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.photo, color: Color(0xFF9A8FA5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.category,
            style: const TextStyle(
              color: Color(0xFF7F758B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '₹${product.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF241132),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: const Color(0xFF4A3A59)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF9A8FA5)),
          SizedBox(height: 10),
          Text(
            'No products match your filters.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF241132),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try adjusting search, category, or stock filters.',
            style: TextStyle(color: Color(0xFF7F758B)),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
