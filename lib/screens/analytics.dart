import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'customer.dart';
import 'slider.dart';
import 'delivery.dart';
import '../services/dashboard_repository.dart';
import '../services/orders_repository.dart';
import '../services/products_repository.dart';

enum AnalyticsRange { week, month, year }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final OrdersRepository _ordersRepository = OrdersRepository();
  final ProductsRepository _productsRepository = ProductsRepository();

  bool _loading = true;
  String? _error;
  StoreInfo? _storeInfo;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      int online = 0;
      int walkIn = 0;
      int delivered = 0;

      for (final o in orders) {
        revenue += o.amount;
        if (o.channel == OrderChannel.walkIn) {
          walkIn += 1;
        } else {
          online += 1;
        }
        if (o.status == OrderStatus.delivered) delivered += 1;
      }

      final categories = <String, int>{};
      for (final p in products) {
        final name = p.categoryTag.isNotEmpty ? p.categoryTag : p.category;
        if (name.isEmpty) continue;
        categories[name] = (categories[name] ?? 0) + 1;
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

        _categoryBreakdown = categories;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SalesPoint> get _activeSales => switch (_range) {
    AnalyticsRange.week => _weekSales,
    AnalyticsRange.month => _monthSales,
    AnalyticsRange.year => _yearSales,
  };

  double get _activeSalesTotal => _activeSales.fold(0, (a, b) => a + b.value);

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
        onOpenProducts: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
        },
        onOpenCustomers: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CustomerScreen()));
        },
        onOpenDelivery: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DeliveryScreen()));
        },
        onOpenAnalytics: () => Navigator.of(context).pop(),
        activeAnalytics: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
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
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(accent: accent, store: _storeInfo),
                const SizedBox(height: 12),
                const _TitleBlock(),
                const SizedBox(height: 14),
                _FiltersRow(accent: accent),
                const SizedBox(height: 16),
                if (_error != null)
                  _ErrorBanner(message: _error!, onRetry: _load)
                else if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _SummaryGrid(
                    accent: accent,
                    totalRevenue: _totalRevenue,
                    totalOrders: _totalOrders,
                    avgOrderValue: _avgOrderValue,
                    totalCustomers: _totalCustomers,
                  ),
                  const SizedBox(height: 14),
                  _SalesOverview(
                    accent: accent,
                    range: _range,
                    onRangeChanged: (value) => setState(() => _range = value),
                    total: _activeSalesTotal,
                    orders: _totalOrders,
                    series: _activeSales,
                  ),
                  const SizedBox(height: 14),
                  _OrderSources(online: _onlineOrders, walkIn: _walkInOrders),
                  const SizedBox(height: 14),
                  const _TopSellingProducts(),
                  const SizedBox(height: 14),
                  _ProductsByCategory(data: _categoryBreakdown),
                  const SizedBox(height: 14),
                  _PerformanceSummary(
                    completionRate: _totalOrders == 0
                        ? 0
                        : _deliveredOrders / _totalOrders,
                    onlineOrders: _onlineOrders,
                    walkInOrders: _walkInOrders,
                    customerBase: _totalCustomers,
                  ),
                ],
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

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Analytics',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF241132),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Track your store performance',
          style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
        ),
      ],
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterButton(
          label: 'All Time',
          icon: Icons.calendar_today_outlined,
          accent: accent,
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF4A3A59),
          ),
        ),
        const SizedBox(width: 10),
        _FilterButton(
          label: 'Export',
          icon: Icons.download_outlined,
          accent: accent,
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A3A59), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF241132),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.accent,
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.totalCustomers,
  });

  final Color accent;
  final double totalRevenue;
  final int totalOrders;
  final double avgOrderValue;
  final int totalCustomers;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        label: 'Total Revenue',
        value: '₹${totalRevenue.toStringAsFixed(0)}',
        subtitle: 'From $totalOrders orders',
        icon: Icons.currency_rupee_rounded,
        tint: const Color(0xFF7AC79A),
      ),
      _SummaryCard(
        label: 'Total Orders',
        value: '$totalOrders',
        subtitle: 'No deliveries yet',
        icon: Icons.shopping_cart_checkout_outlined,
        tint: const Color(0xFF9BB9FF),
      ),
      _SummaryCard(
        label: 'Avg Order Value',
        value: '₹${avgOrderValue.toStringAsFixed(0)}',
        subtitle: 'Per order',
        icon: Icons.trending_up_outlined,
        tint: const Color(0xFFD9C8FF),
      ),
      _SummaryCard(
        label: 'Total Customers',
        value: '$totalCustomers',
        subtitle: 'Active customers',
        icon: Icons.groups_outlined,
        tint: const Color(0xFFF8D7B4),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF4A3A59))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF0F8A44), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SalesOverview extends StatelessWidget {
  const _SalesOverview({
    required this.accent,
    required this.range,
    required this.onRangeChanged,
    required this.total,
    required this.orders,
    required this.series,
  });

  final Color accent;
  final AnalyticsRange range;
  final ValueChanged<AnalyticsRange> onRangeChanged;
  final double total;
  final int orders;
  final List<SalesPoint> series;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${total.toStringAsFixed(0)} from $orders orders',
            style: const TextStyle(color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 12),
          _RangeTabs(range: range, onChanged: onRangeChanged),
          const SizedBox(height: 10),
          _SalesChart(series: series, accent: accent),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.range, required this.onChanged});

  final AnalyticsRange range;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF4D0E7F);

    Widget pill(String label, AnalyticsRange value) {
      final isActive = range == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? selectedColor : const Color(0xFFF4EEF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF4A3A59),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('Week', AnalyticsRange.week),
        const SizedBox(width: 8),
        pill('Month', AnalyticsRange.month),
        const SizedBox(width: 8),
        pill('Year', AnalyticsRange.year),
      ],
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.series, required this.accent});

  final List<SalesPoint> series;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FD),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
        painter: _SalesChartPainter(series: series, color: accent),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  _SalesChartPainter({required this.series, required this.color});

  final List<SalesPoint> series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) {
      final paint = Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final y = size.height * 0.8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final values = series.map((p) => p.value).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.01 ? 1 : maxValue - minValue;

    final points = <Offset>[];
    final denom = (series.length - 1).clamp(1, 1000000);
    for (var i = 0; i < series.length; i++) {
      final x = i / denom * size.width;
      final norm = (values[i] - minValue) / range;
      final y = size.height - norm * (size.height * 0.75) - size.height * 0.1;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.2), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawPath(area, areaPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.color != color;
  }
}

class _OrderSources extends StatelessWidget {
  const _OrderSources({required this.online, required this.walkIn});

  final int online;
  final int walkIn;

  @override
  Widget build(BuildContext context) {
    final data = {'Online': online, 'Walk-in': walkIn};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Sources',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Online vs Walk-in orders',
            style: TextStyle(color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 12),
          Center(
            child: _DonutChart(
              data: data,
              colors: const [Color(0xFF5B6BFF), Color(0xFFB0B5FF)],
              size: 180,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: Color(0xFF5B6BFF), label: 'Online'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFFB0B5FF), label: 'Walk-in'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopSellingProducts extends StatelessWidget {
  const _TopSellingProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Top Selling Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          SizedBox(height: 4),
          Text('By quantity sold', style: TextStyle(color: Color(0xFF7F758B))),
          SizedBox(height: 40),
          Center(
            child: Text(
              'No sales data yet',
              style: TextStyle(color: Color(0xFF7F758B)),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ProductsByCategory extends StatelessWidget {
  const _ProductsByCategory({required this.data});

  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final hasData = data.isNotEmpty;
    final list = hasData
        ? data.entries.toList()
        : const <MapEntry<String, int>>[];

    final colors = const [
      Color(0xFF4D0E7F),
      Color(0xFF8C3AE3),
      Color(0xFFB57CFF),
      Color(0xFFE0C3FF),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribution of your catalogue',
            style: TextStyle(color: Color(0xFF7F758B)),
          ),
          const SizedBox(height: 12),
          Center(
            child: _DonutChart(
              data: hasData ? Map.fromEntries(list) : {'': 1},
              colors: colors,
              size: 180,
            ),
          ),
          const SizedBox(height: 12),
          if (hasData)
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (var i = 0; i < list.length; i++)
                  _LegendDot(
                    color: colors[i % colors.length],
                    label: list[i].key,
                  ),
              ],
            )
          else
            const Center(
              child: Text(
                'No category data yet',
                style: TextStyle(color: Color(0xFF7F758B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PerformanceSummary extends StatelessWidget {
  const _PerformanceSummary({
    required this.completionRate,
    required this.onlineOrders,
    required this.walkInOrders,
    required this.customerBase,
  });

  final double completionRate;
  final int onlineOrders;
  final int walkInOrders;
  final int customerBase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Order Completion Rate',
            valueLabel: '${(completionRate * 100).toStringAsFixed(0)}%',
            percent: completionRate,
            color: const Color(0xFF4D0E7F),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: 'Online Orders',
            valueLabel: '$onlineOrders orders',
            percent: _clampPercent(onlineOrders, onlineOrders + walkInOrders),
            color: const Color(0xFF4D0E7F),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: 'Walk-in Orders',
            valueLabel: '$walkInOrders orders',
            percent: _clampPercent(walkInOrders, onlineOrders + walkInOrders),
            color: const Color(0xFF8B7F95),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: 'Customer Base',
            valueLabel: '$customerBase customers',
            percent: customerBase == 0 ? 0 : 1,
            color: const Color(0xFF4D0E7F),
          ),
        ],
      ),
    );
  }
}

double _clampPercent(int part, int total) {
  if (total <= 0) return 0;
  final v = part / total;
  return v.clamp(0, 1).toDouble();
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.valueLabel,
    required this.percent,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4A3A59),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(valueLabel, style: const TextStyle(color: Color(0xFF4A3A59))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 8,
            backgroundColor: const Color(0xFFE6E2EE),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

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
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(data: data, colors: colors),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.data, required this.colors});

  final Map<String, int> data;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (sum, v) => sum + v);
    final rect = Offset.zero & size;
    final stroke = size.width * 0.12;

    final basePaint = Paint()
      ..color = const Color(0xFFE7E3F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;

    canvas.drawCircle(center, radius, basePaint);

    if (total <= 0) return;

    double start = -90;
    var index = 0;
    for (final entry in data.entries) {
      final sweep = entry.value / total * 360;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start * 3.1415926535 / 180,
        sweep * 3.1415926535 / 180,
        false,
        paint,
      );
      start += sweep;
      index += 1;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.colors != colors;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A3A59),
            fontWeight: FontWeight.w700,
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

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
