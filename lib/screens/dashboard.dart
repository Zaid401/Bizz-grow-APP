import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import 'slider.dart';
import 'posBilling.dart';
import 'orders.dart';
import 'products.dart';
import 'Analytics.dart';
import 'customer.dart';
import 'delivery.dart';

enum SalesRange { week, month, year }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _repository = DashboardRepository();

  DashboardData? _data;
  bool _loading = true;
  String? _error;
  SalesRange _selectedRange = SalesRange.week;

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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.fetch();
      if (!mounted) return;
      setState(() => _data = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F5FB);
    const accent = Color(0xFF4D0E7F);
    const cardRadius = 16.0;

    final data = _data ?? _fallbackData;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: DashboardDrawer(
        store: data.storeInfo,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
        onOpenPosBilling: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PosBillingScreen()));
        },
        onOpenOrders: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
        },
        onOpenProducts: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
        },
        onOpenCustomers: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CustomerScreen()));
        },
        onOpenAnalytics: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
        },
        onOpenDelivery: () {
          _scaffoldKey.currentState?.closeDrawer();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DeliveryScreen()));
        },
        activeDashboard: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF8B7F95),
        onTap: (index) {
          if (index == 1) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
          } else if (index == 2) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
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
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) _errorBanner(_error!),
                _topBar(accent, data.storeInfo),
                const SizedBox(height: 16),
                _welcomeCard(accent, cardRadius, data.storeInfo),
                const SizedBox(height: 16),
                _statsGrid(cardRadius, data),
                const SizedBox(height: 16),
                _quickActions(cardRadius),
                const SizedBox(height: 16),
                _salesOverview(cardRadius, accent, data),
                const SizedBox(height: 16),
                _recentOrders(cardRadius, accent, data.recentOrders),
                const SizedBox(height: 16),
                _todaySummary(cardRadius, accent, data),
                const SizedBox(height: 16),
                _tips(cardRadius),
                const SizedBox(height: 16),
                _stockStatus(cardRadius, data.productsCount),
                const SizedBox(height: 16),
                _storeInfo(cardRadius, data.storeInfo),
                if (_loading) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(Color accent, StoreInfo? store) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF4A3A59)),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF4A3A59),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.headphones_outlined, color: Color(0xFF4A3A59)),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
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

  Widget _welcomeCard(Color accent, double radius, StoreInfo? store) {
    final storeName = store?.name ?? 'My Store';
    final storeCategory = store?.category ?? 'Other Retail';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFF8C6BFF), Color(0xFF6B4CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.store_mall_directory_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                storeCategory,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Good afternoon 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to $storeName!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your store is ready for business! Start by adding products.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text(
                'Add Products with AI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(double radius, DashboardData data) {
    final cards = [
      _statTile(
        "Today's Revenue",
        '₹${_formatCurrency(data.revenueToday)}',
        data.revenueToday == 0 ? 'No orders yet' : 'Revenue counted for today',
        Icons.payments_outlined,
        const Color(0xFF2EC28B),
      ),
      _statTile(
        'Orders',
        '${data.ordersToday}',
        data.ordersToday == 0 ? 'No orders yet' : 'Orders placed today',
        Icons.all_inbox_outlined,
        const Color(0xFF8D9CF6),
      ),
      _statTile(
        'Products',
        '${data.productsCount}',
        data.productsCount == 0 ? 'Add your first product' : 'Total products',
        Icons.storefront_outlined,
        const Color(0xFF9B59B6),
      ),
      _statTile(
        'Customers',
        '${data.customersCount}',
        data.customersCount == 0 ? 'No customers yet' : 'Total customers',
        Icons.groups_outlined,
        const Color(0xFFF39C12),
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

  Widget _statTile(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color tint,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A3A59),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: tint.withOpacity(0.15),
                child: Icon(icon, size: 18, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(double radius) {
    final actions = [
      _ActionItem(
        'Add Product',
        'New Products',
        Icons.inventory_2_outlined,
        const Color(0xFF00B8D9),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
        },
      ),
      _ActionItem(
        'AI Upload',
        'Photo to product',
        Icons.auto_awesome_motion,
        const Color(0xFF8E54E9),
      ),
      _ActionItem(
        'Delivery',
        'Manage routes',
        Icons.local_shipping_outlined,
        const Color(0xFF4B8BFF),
      ),
      _ActionItem(
        'Subscriptions',
        'Daily customers',
        Icons.access_time,
        const Color(0xFF13B38B),
      ),
      _ActionItem(
        'Share Store',
        'Get your store link',
        Icons.widgets_outlined,
        const Color(0xFF00A2FF),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.store_mall_directory_outlined,
                color: Color(0xFF4D0E7F),
              ),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF241132),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Common tasks for your retail',
            style: TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map<Widget>(
                  (item) => _actionTile(
                    item.title,
                    item.subtitle,
                    item.icon,
                    item.tint,
                    onTap: item.onTap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    String title,
    String subtitle,
    IconData icon,
    Color tint, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 160,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3DFEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tint.withOpacity(0.15),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C1937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F758B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _salesOverview(double radius, Color accent, DashboardData data) {
    final points = _seriesForRange(data);
    final hasSales = points.any((p) => p.value > 0);
    final rangeTotal = points.fold<double>(0, (sum, p) => sum + p.value);
    final rangeLabel = _rangeLabel(_selectedRange);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_formatCurrency(data.revenueToday)} from ${data.ordersToday} orders',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EEF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _tabChip(
                  'Week',
                  _selectedRange == SalesRange.week,
                  accent,
                  () => _setRange(SalesRange.week),
                ),
                _tabChip(
                  'Month',
                  _selectedRange == SalesRange.month,
                  accent,
                  () => _setRange(SalesRange.month),
                ),
                _tabChip(
                  'Year',
                  _selectedRange == SalesRange.year,
                  accent,
                  () => _setRange(SalesRange.year),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SalesChart(
            points: points,
            accent: accent,
            formatValue: _formatCurrency,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${_formatCurrency(rangeTotal)} this $rangeLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF241132),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasSales)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EEF9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.trending_up, color: accent),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Sales data refreshed automatically',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Totals calculated from recent orders',
                          style: TextStyle(
                            color: Color(0xFF4A3A59),
                            fontSize: 12,
                          ),
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
                children: const [
                  Text(
                    'No sales data for this period',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Orders will show up here once placed',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9A8FA5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabChip(
    String label,
    bool selected,
    Color accent,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF4A3A59),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _setRange(SalesRange range) {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
  }

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
    return List.generate(days, (index) {
      final date = start.add(Duration(days: index));
      return SalesPoint(
        date: date,
        value: 0,
        label: _weekdayLabel(date.weekday),
      );
    });
  }

  List<SalesPoint> _placeholderMonths(int year) {
    return List.generate(12, (index) {
      final date = DateTime.utc(year, index + 1, 1);
      return SalesPoint(date: date, value: 0, label: _monthLabel(date.month));
    });
  }

  String _rangeLabel(SalesRange range) {
    switch (range) {
      case SalesRange.week:
        return 'week';
      case SalesRange.month:
        return 'month';
      case SalesRange.year:
        return 'year';
    }
  }

  Widget _recentOrders(double radius, Color accent, List<RecentOrder> orders) {
    final hasOrders = orders.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF241132),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Latest customer orders',
            style: TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 26),
          if (hasOrders)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 18, color: Color(0xFFEDE9F3)),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFF4A3A59),
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
                              color: Color(0xFF241132),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.id} · ${_formatOrderDate(order.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7F758B),
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
                            color: Color(0xFF241132),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _statusChip(order.status),
                      ],
                    ),
                  ],
                );
              },
            )
          else
            Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.widgets_outlined,
                    size: 42,
                    color: Color(0xFF7F758B),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Orders will appear here',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9A8FA5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _todaySummary(double radius, Color accent, DashboardData data) {
    final items = [
      _summaryTile(
        "Today's Revenue",
        '₹${_formatCurrency(data.revenueToday)}',
        data.ordersToday == 0 ? 'No change yet' : 'Live from Supabase',
        Icons.payments_outlined,
        const Color(0xFF2EC28B),
      ),
      _summaryTile(
        'Orders Today',
        '${data.ordersToday}',
        data.ordersToday == 0
            ? '0 pending · 0 done'
            : '${data.ordersToday} placed today',
        Icons.receipt_long_outlined,
        const Color(0xFF7B8CF9),
      ),
      _summaryTile(
        'Products',
        '${data.productsCount}',
        data.productsCount == 0
            ? 'Add your first product'
            : 'Total catalog size',
        Icons.storefront_outlined,
        const Color(0xFF9B59B6),
      ),
      _summaryTile(
        'Customers',
        '${data.customersCount}',
        data.customersCount == 0
            ? 'No customers yet'
            : 'Customers in your store',
        Icons.groups_outlined,
        const Color(0xFFEB8C34),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up, color: Color(0xFF4D0E7F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF241132),
                  ),
                ),
              ),
              Text(
                'Auto-updates every 30s',
                style: TextStyle(fontSize: 12, color: Color(0xFF7F758B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map((item) => SizedBox(width: itemWidth, child: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color tint,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A3A59),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: tint.withOpacity(0.15),
                child: Icon(icon, size: 18, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F758B)),
          ),
        ],
      ),
    );
  }

  Widget _tips(double radius) {
    final tips = [
      _TipItem('Daily Delivery', 'Set up recurring deliveries'),
      _TipItem('Fresh Stock', 'Update stock daily for freshness'),
      _TipItem('Expiry Tracking', 'Monitor product shelf life'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFF00B8D9)),
              SizedBox(width: 8),
              Text(
                'Tips for Dairy Shop',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF241132),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Grow your business',
            style: TextStyle(fontSize: 13, color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 12),
          Column(
            children: tips
                .map(
                  (tip) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF00B8D9),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C1937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7F758B),
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
        ],
      ),
    );
  }

  Widget _stockStatus(double radius, int productCount) {
    final hasProducts = productCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_rounded, color: Color(0xFF4D0E7F)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stock Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF241132),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasProducts
                      ? '$productCount products live'
                      : 'Add products to start selling',
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

  Widget _storeInfo(double radius, StoreInfo? store) {
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
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE3DFEA)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFF2BB4F7), Color(0xFF18D1D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_drink_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.category,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(label: 'Store Name', value: info.name),
                const SizedBox(height: 10),
                _InfoRow(label: 'Category', value: info.category),
                const SizedBox(height: 10),
                _InfoRow(label: 'Mode', value: info.mode),
                const SizedBox(height: 10),
                _InfoRow(label: 'Location', value: info.location),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Status',
                  value: info.status,
                  valueColor: isActive
                      ? const Color(0xFF2EC28B)
                      : const Color(0xFF7F758B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();

    Color bg = const Color(0xFFE3DFEA);
    Color fg = const Color(0xFF4A3A59);
    String label = status.isEmpty ? 'Pending' : status;

    if (normalized.contains('deliver') || normalized.contains('complete')) {
      bg = const Color(0xFFDEF7EC);
      fg = const Color(0xFF0F5132);
      label = 'Delivered';
    } else if (normalized.contains('cancel')) {
      bg = const Color(0xFFFDE2E4);
      fg = const Color(0xFF9B1C1C);
      label = 'Cancelled';
    } else if (normalized.contains('pending')) {
      bg = const Color(0xFFFFF4E5);
      fg = const Color(0xFF8B5E00);
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _formatOrderDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      return 'Today ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    }

    if (diff.inDays == 1) {
      return 'Yesterday';
    }

    return '${_twoDigits(local.day)} ${_monthLabel(local.month)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _weekdayLabel(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekday < 1 || weekday > 7) return '--';
    return names[weekday - 1];
  }

  String _monthLabel(int month) {
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
    if (month < 1 || month > 12) return '--';
    return months[month - 1];
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2C46D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF8B5E00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF5C4200), fontSize: 13),
            ),
          ),
          TextButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }
}

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
          height: 180,
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
                          fontSize: 11,
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
        const SizedBox(height: 12),
        Row(
          children: labelIndexes
              .map(
                (index) => Expanded(
                  child: Text(
                    points[index].label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7F758B),
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
    if (maxY <= 0) {
      return const [0, 0.25, 0.5, 0.75, 1];
    }
    final step = maxY / 4;
    return List.generate(5, (i) => step * i);
  }

  List<int> _labelIndexes(int length) {
    if (length <= 1) return [0];
    if (length <= 8) return List.generate(length, (i) => i);

    final set = <int>{0, length - 1};
    final step = (length - 1) / 6;
    for (int i = 1; i <= 5; i++) {
      set.add((i * step).round());
    }
    final items = set.toList()..sort();
    return items;
  }
}

class _SalesAreaPainter extends CustomPainter {
  _SalesAreaPainter({
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

    final width = size.width;
    final height = size.height;
    final baseline = height - 4;
    final drawableHeight = height - 12;

    final gridPaint = Paint()
      ..color = accent.withOpacity(0.08)
      ..strokeWidth = 1;

    for (final tick in ticks.where((v) => v > 0)) {
      final y = baseline - (tick / maxY) * drawableHeight;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final stepX = points.length <= 1 ? 0.0 : width / (points.length - 1);
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = stepX * i;
      final y = baseline - (points[i].value / maxY) * drawableHeight;
      final clampedY = y.clamp(0.0, height);
      offsets.add(
        Offset(x, clampedY is double ? clampedY : (clampedY as num).toDouble()),
      );
    }

    final areaPath = Path()..moveTo(0, baseline);
    for (final o in offsets) {
      areaPath.lineTo(o.dx, o.dy);
    }
    areaPath.lineTo(width, baseline);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [accent.withOpacity(0.2), accent.withOpacity(0.05)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      linePath.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = accent;
    for (final o in offsets) {
      canvas.drawCircle(o, 3.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesAreaPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accent != accent ||
        oldDelegate.maxY != maxY;
  }
}

class _ActionItem {
  const _ActionItem(
    this.title,
    this.subtitle,
    this.icon,
    this.tint, {
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
}

class _TipItem {
  const _TipItem(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF241132),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4A3A59),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
