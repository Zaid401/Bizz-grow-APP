import 'package:flutter/material.dart';

import '../services/orders_repository.dart';
import '../widgets/order_detail_screen.dart';

class PosDuePaymentsScreen extends StatefulWidget {
  const PosDuePaymentsScreen({super.key});

  @override
  State<PosDuePaymentsScreen> createState() => _PosDuePaymentsScreenState();
}

class _PosDuePaymentsScreenState extends State<PosDuePaymentsScreen> {
  final OrdersRepository _ordersRepository = OrdersRepository();
  final TextEditingController _search = TextEditingController();

  List<OrderRecord> _orders = const [];
  bool _loading = true;
  String? _error;

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
      final orders = await _ordersRepository.fetchOrders();
      final enriched = await Future.wait(
        orders.map((order) async {
          final summary = await _ordersRepository.fetchPaymentSummaryForOrder(
            order.id,
          );
          if (summary == null) return order;
          return OrderRecord(
            id: order.id,
            invoiceId: summary.invoiceId,
            customer: order.customer,
            phone: order.phone,
            items: order.items,
            amount: summary.totalAmount > 0
                ? summary.totalAmount
                : order.amount,
            paidAmount: summary.paidAmount,
            remainingAmount: summary.remainingAmount,
            itemLines: order.itemLines,
            channel: order.channel,
            status: order.status,
            paymentMethod: order.paymentMethod,
            createdAt: order.createdAt,
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _orders = enriched.where((o) => (o.remainingAmount ?? 0) > 0).toList()
          ..sort(
            (a, b) =>
                (b.remainingAmount ?? 0).compareTo(a.remainingAmount ?? 0),
          );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<OrderRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders
        .where(
          (o) =>
              o.customer.toLowerCase().contains(q) ||
              o.invoiceId.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Due Payments'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF23152F),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by customer or invoice...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF4A3A59),
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
              ),
              const SizedBox(height: 14),
              if (_error != null)
                _ErrorBanner(message: _error!, onRetry: _load)
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filtered.isEmpty)
                const _EmptyDuePayments()
              else
                _PendingPaymentsSection(
                  payments: _filtered,
                  onOpenOrder: (order) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: order),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingPaymentsSection extends StatelessWidget {
  const _PendingPaymentsSection({
    required this.payments,
    required this.onOpenOrder,
  });

  final List<OrderRecord> payments;
  final ValueChanged<OrderRecord> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF6D7A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timelapse, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Partial Payments (${payments.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9A5A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...payments.map(
            (order) => _PendingPaymentCard(
              order: order,
              onPay: () => onOpenOrder(order),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.order, required this.onPay});

  final OrderRecord order;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final paid = order.paidAmount ?? 0;
    final due = order.remainingAmount ?? 0;
    final label = order.invoiceId.isNotEmpty ? order.invoiceId : order.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1D7AD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B5E85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.customer,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF23152F),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Paid ₹${_formatPrice(paid)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Due ₹${_formatPrice(due)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: onPay,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF2C46D)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text(
                'Pay',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDuePayments extends StatelessWidget {
  const _EmptyDuePayments();

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
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: Color(0xFFB2A9BD)),
          SizedBox(height: 10),
          Text(
            'No due payments',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F758B)),
          ),
          SizedBox(height: 6),
          Text(
            'You are all caught up!',
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
