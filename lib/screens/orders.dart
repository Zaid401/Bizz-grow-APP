import 'package:flutter/material.dart';

import 'slider.dart';
import 'dashboard.dart';
import 'posBilling.dart';
import 'products.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'delivery.dart';
import '../services/orders_repository.dart';
import '../services/dashboard_repository.dart';

enum OrderChannel { all, online, walkIn }

enum OrderStatus { all, pending, confirmed, delivering, delivered }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderChannel _selectedChannel = OrderChannel.all;
  OrderStatus _selectedStatus = OrderStatus.all;

  final OrdersRepository _repository = OrdersRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  StoreInfo? _storeInfo;
  List<OrderRecord> _orders = const [];
  bool _loading = true;
  String? _error;

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
      final results = await _repository.fetchOrders();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _orders = results;
        _storeInfo = dash.storeInfo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F5FB);
    const accent = Color(0xFF4D0E7F);
    const soft = Color(0xFFF0EAF7);
    const textPrimary = Color(0xFF241132);
    const textSecondary = Color(0xFF7F758B);

    final filtered = _orders.where((o) {
      final channelOk =
          _selectedChannel == OrderChannel.all || o.channel == _selectedChannel;
      final statusOk =
          _selectedStatus == OrderStatus.all || o.status == _selectedStatus;
      return channelOk && statusOk;
    }).toList();

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
      backgroundColor: bg,
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
        onOpenOrders: () {},
        activeOrders: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF8B7F95),
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else if (index == 1) {
            // stay
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(accent: accent, store: _storeInfo),
                const SizedBox(height: 12),
                const _Title(),
                const SizedBox(height: 16),
                _Filters(accent: accent),
                const SizedBox(height: 16),
                _StatsGrid(
                  accent: accent,
                  total: totalOrders,
                  online: onlineOrders,
                  walkIn: walkInOrders,
                  pending: pendingOrders,
                ),
                const SizedBox(height: 12),
                _OrderTypeTabs(
                  selected: _selectedChannel,
                  onChanged: (channel) =>
                      setState(() => _selectedChannel = channel),
                ),
                const SizedBox(height: 12),
                _StatusChips(
                  selected: _selectedStatus,
                  onChanged: (status) =>
                      setState(() => _selectedStatus = status),
                ),
                const SizedBox(height: 14),
                const _SearchRow(),
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
                else if (filtered.isEmpty)
                  const _EmptyOrders()
                else
                  Column(
                    children: filtered
                        .map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OrderCard(
                              order: order,
                              accent: accent,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              soft: soft,
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.accent, required this.store});

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
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF4A3A59),
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.volume_off, color: Color(0xFF4A3A59)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.dnd_forwardslash, color: Color(0xFF4A3A59)),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
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

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orders',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage and track customer orders',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterButton(
          label: 'Today',
          icon: Icons.today_outlined,
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
          icon: Icons.ios_share_outlined,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.accent,
    required this.total,
    required this.online,
    required this.walkIn,
    required this.pending,
  });

  final Color accent;
  final int total;
  final int online;
  final int walkIn;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: 'Total Orders',
        value: '$total',
        icon: Icons.shopping_bag_outlined,
        tint: accent,
      ),
      _StatCard(
        label: 'Online',
        value: '$online',
        icon: Icons.language_outlined,
        tint: const Color(0xFF9C76D2),
      ),
      _StatCard(
        label: 'Walk-in',
        value: '$walkIn',
        icon: Icons.directions_car_outlined,
        tint: const Color(0xFF2EC28B),
      ),
      _StatCard(
        label: 'Pending',
        value: '$pending',
        icon: Icons.schedule_outlined,
        tint: const Color(0xFFE3AA44),
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241132),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
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
}

class _OrderTypeTabs extends StatelessWidget {
  const _OrderTypeTabs({required this.selected, required this.onChanged});

  final OrderChannel selected;
  final ValueChanged<OrderChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF4D0E7F);
    const unselected = Color(0xFF4A3A59);

    Widget pill(IconData icon, String label, OrderChannel channel) {
      final isActive = selected == channel;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(channel),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? selectedColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3DFEA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.white : unselected,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : unselected,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(Icons.shopping_bag_outlined, 'All', OrderChannel.all),
        pill(Icons.language_outlined, 'Online', OrderChannel.online),
        pill(
          Icons.store_mall_directory_outlined,
          'Walk-in',
          OrderChannel.walkIn,
        ),
        Container(
          margin: const EdgeInsets.only(left: 6),
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: selectedColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.volume_up_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onChanged});

  final OrderStatus selected;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    const chipBg = Color(0xFFEDE6F4);
    const selectedBg = Color(0xFFDCD2EE);

    Widget chip(String label, OrderStatus status) {
      final isActive = selected == status;
      return GestureDetector(
        onTap: () => onChanged(status),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? selectedBg : chipBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A3A59),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All Status', OrderStatus.all),
          const SizedBox(width: 10),
          chip('Pending', OrderStatus.pending),
          const SizedBox(width: 10),
          chip('Confirmed', OrderStatus.confirmed),
          const SizedBox(width: 10),
          chip('Delivering', OrderStatus.delivering),
          const SizedBox(width: 10),
          chip('Delivered', OrderStatus.delivered),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search orders...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4A3A59)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
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
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3DFEA)),
          ),
          child: const Icon(Icons.filter_list, color: Color(0xFF4A3A59)),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.soft,
  });

  final OrderRecord order;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final channelPill = order.channel == OrderChannel.online
        ? _Pill(label: 'Online', color: const Color(0xFFB49BE0))
        : _Pill(
            label: 'Walk-in',
            color: const Color(0xFFBEE4D3),
            textColor: const Color(0xFF0F5132),
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                order.id,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              channelPill,
              _Pill(
                label: _statusLabel(order.status),
                color: const Color(0xFFF4C16C),
              ),
              _Pill(
                label: order.paymentMethod,
                color: const Color(0xFFDBE5FF),
                textColor: const Color(0xFF4A3A59),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Color(0xFF7F758B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.customer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A3A59),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Color(0xFF7F758B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${order.items} items',
                    style: const TextStyle(color: Color(0xFF7F758B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Color(0xFF7F758B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _timeAgo(order.createdAt),
                    style: const TextStyle(color: Color(0xFF7F758B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '₹${order.amount}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              _IconButton(icon: Icons.phone_outlined),
              const SizedBox(width: 12),
              _IconButton(icon: Icons.chat_bubble_outline),
              const SizedBox(width: 12),
              _IconButton(icon: Icons.remove_red_eye_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _dateLabel(order.createdAt),
            style: const TextStyle(color: Color(0xFF7F758B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.textColor});

  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF4A3A59)),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 42, color: Color(0xFFB2A9BD)),
          SizedBox(height: 10),
          Text(
            'No orders in this view',
            style: TextStyle(
              color: Color(0xFF4A3A59),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Switch tabs or refresh to see orders.',
            style: TextStyle(color: Color(0xFF7F758B), fontSize: 13),
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
  final now = DateTime.now().toUtc();
  final diff = now.difference(createdAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return 'about ${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return 'about ${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'about 1 day ago';
  return 'about ${diff.inDays} days ago';
}

String _dateLabel(DateTime createdAt) {
  final local = createdAt.toLocal();
  final months = [
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
  final day = local.day.toString().padLeft(2, '0');
  final month = months[local.month - 1];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$month $day, $hour:$minute $period';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? 'S' : letters.toUpperCase();
}
