import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'orders.dart';
import 'products.dart';
import 'posBilling.dart';
import 'customer.dart';
import 'Analytics.dart';
import 'slider.dart';
import '../services/delivery_repository.dart';
import '../services/dashboard_repository.dart';

enum DeliveryFilter { all, pending, inTransit, delivered }

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final DeliveryRepository _repository = DeliveryRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final TextEditingController _search = TextEditingController();

  List<DeliveryRecord> _deliveries = const [];
  StoreInfo? _storeInfo;
  bool _loading = true;
  String? _error;
  DeliveryFilter _filter = DeliveryFilter.all;

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
      final results = await _repository.fetchDeliveries();
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() {
        _deliveries = results;
        _storeInfo = dash.storeInfo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DeliveryRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _deliveries.where((d) {
      final matchesQuery = q.isEmpty
          ? true
          : d.id.toLowerCase().contains(q) ||
                d.customer.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        DeliveryFilter.all => true,
        DeliveryFilter.pending => d.status == DeliveryStatus.pending,
        DeliveryFilter.inTransit => d.status == DeliveryStatus.inTransit,
        DeliveryFilter.delivered =>
          d.status == DeliveryStatus.delivered ||
              d.status == DeliveryStatus.completed,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  int get _totalDeliveries => _deliveries.length;
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

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4D0E7F);
    const bg = Color(0xFFF7F5FB);
    const soft = Color(0xFFF4EEF9);

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
        onOpenAnalytics: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
        },
        onOpenDelivery: () => Navigator.of(context).pop(),
        activeDelivery: true,
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
                _TopBar(accent: accent, store: _storeInfo),
                const SizedBox(height: 10),
                const _TitleBlock(),
                const SizedBox(height: 12),
                _ActionsRow(accent: accent),
                const SizedBox(height: 16),
                _StatsGrid(
                  accent: accent,
                  soft: soft,
                  total: _totalDeliveries,
                  inTransit: _inTransit,
                  completed: _completed,
                  pending: _pending,
                ),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _FilterChips(
                  selected: _filter,
                  onChanged: (value) => setState(() => _filter = value),
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
                else if (_filtered.isEmpty)
                  const _EmptyState()
                else
                  Column(
                    children: _filtered
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DeliveryCard(delivery: d, accent: accent),
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
        _BadgeIcon(icon: Icons.notifications_none_rounded, count: 1),
        const SizedBox(width: 6),
        _BadgeIcon(icon: Icons.headset_mic_outlined, count: 1),
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
  const _BadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

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
            border: Border.all(color: const Color(0xFFE3DFEA)),
          ),
          child: Icon(icon, color: const Color(0xFF4A3A59), size: 18),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFB3261E),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241132),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Track and manage all deliveries',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3DFEA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF4A3A59),
                ),
                SizedBox(width: 8),
                Text(
                  'Today',
                  style: TextStyle(
                    color: Color(0xFF241132),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF4A3A59),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {},
            icon: const Icon(Icons.auto_graph_rounded, size: 18),
            label: const Text(
              'Optimize Route',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.accent,
    required this.soft,
    required this.total,
    required this.inTransit,
    required this.completed,
    required this.pending,
  });

  final Color accent;
  final Color soft;
  final int total;
  final int inTransit;
  final int completed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        final cards = [
          _StatCard(
            title: 'Total Deliveries',
            value: total,
            icon: Icons.local_shipping_outlined,
            accent: accent,
            soft: soft,
          ),
          _StatCard(
            title: 'In Transit',
            value: inTransit,
            icon: Icons.send_rounded,
            accent: const Color(0xFF7A5AF8),
            soft: soft,
          ),
          _StatCard(
            title: 'Completed',
            value: completed,
            icon: Icons.check_circle_outline,
            accent: const Color(0xFF2EC28B),
            soft: soft,
          ),
          _StatCard(
            title: 'Pending',
            value: pending,
            icon: Icons.schedule_outlined,
            accent: const Color(0xFFFFA53B),
            soft: soft,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.soft,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: soft.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF241132),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7F758B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
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
        hintText: 'Search deliveries...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7F758B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3DFEA)),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final DeliveryFilter selected;
  final ValueChanged<DeliveryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4D0E7F);
    final labels = {
      DeliveryFilter.all: 'All',
      DeliveryFilter.pending: 'Pending',
      DeliveryFilter.inTransit: 'In Transit',
      DeliveryFilter.delivered: 'Delivered',
    };

    return Wrap(
      spacing: 10,
      children: labels.entries.map((entry) {
        final active = entry.key == selected;
        return ChoiceChip(
          label: Text(
            entry.value,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF4A3A59),
              fontWeight: FontWeight.w700,
            ),
          ),
          selected: active,
          onSelected: (_) => onChanged(entry.key),
          selectedColor: accent,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: active ? accent : const Color(0xFFE3DFEA)),
          ),
          elevation: 0,
        );
      }).toList(),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.accent});

  final DeliveryRecord delivery;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusText(delivery.status);
    final statusColor = _statusColor(delivery.status);

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
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF241132),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      delivery.customer,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7F758B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoPill(
                icon: Icons.layers_outlined,
                label: 'Items',
                value: '${delivery.items}',
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.access_time,
                label: 'Time',
                value: _timeAgo(delivery.createdAt),
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.currency_rupee,
                label: 'Amount',
                value: '₹${delivery.amount.toStringAsFixed(0)}',
              ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    onPressed: delivery.phone == null ? null : () {},
                    icon: const Icon(Icons.phone_outlined, size: 20),
                    color: const Color(0xFF4A3A59),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.near_me_outlined, size: 20),
                    color: const Color(0xFF4A3A59),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4A3A59)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7F758B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF241132),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB54D12)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F4A1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 40,
            color: Color(0xFF7F758B),
          ),
          SizedBox(height: 10),
          Text(
            'No deliveries yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF241132),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'New deliveries will appear here once created.',
            style: TextStyle(color: Color(0xFF7F758B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().toUtc().difference(date.toUtc());
  if (diff.inDays >= 1) return '${diff.inDays} days ago';
  if (diff.inHours >= 1) return '${diff.inHours} hrs ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} mins ago';
  return 'Just now';
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'B';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  final combined = (first + last).toUpperCase();
  return combined.isEmpty ? trimmed[0].toUpperCase() : combined;
}

String _statusText(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.pending:
      return 'Pending';
    case DeliveryStatus.inTransit:
      return 'In Transit';
    case DeliveryStatus.delivered:
      return 'Delivered';
    case DeliveryStatus.completed:
      return 'Completed';
  }
}

Color _statusColor(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.pending:
      return const Color(0xFFFFA53B);
    case DeliveryStatus.inTransit:
      return const Color(0xFF7A5AF8);
    case DeliveryStatus.delivered:
    case DeliveryStatus.completed:
      return const Color(0xFF2EC28B);
  }
}
