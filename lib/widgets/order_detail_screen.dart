import 'package:flutter/material.dart';
import 'package:bizz_grow/models/order_types.dart';
import '../services/orders_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final OrderRecord order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F9FB);
    const brand = Color(0xFF8A74A7);
    const brandLight = Color(0xFFF5F3F7);
    const brandBorder = Color(0xFFEBE7F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    /// HEADER
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Order Details",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                "Order ID: ${widget.order.id}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// STATUS BADGE
                    _StatusPill(status: widget.order.status),

                    const SizedBox(height: 30),

                    /// CUSTOMER DETAILS TITLE
                    const Text(
                      "CUSTOMER DETAILS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// CUSTOMER CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: brandBorder),
                      ),
                      child: Column(
                        children: [
                          _CustomerInfoRow(
                            icon: Icons.person,
                            title: widget.order.customer,
                            subtitle: "Primary Customer",
                          ),

                          const SizedBox(height: 14),

                          _CustomerInfoRow(
                            icon: Icons.call,
                            title: widget.order.phone,
                            subtitle: "Customer Phone",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// ORDER SUMMARY
                    const Text(
                      "ORDER SUMMARY",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _OrderItemRow(
                      title: "Items in order",
                      quantity: widget.order.items,
                      amount: widget.order.amount,
                    ),

                    const SizedBox(height: 20),

                    const Divider(),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const Spacer(),

                        Text(
                          "₹${widget.order.amount}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: brand,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// PAYMENT STATUS
                    Row(
                      children: [
                        const Text(
                          "PAYMENT STATUS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                            color: Colors.grey,
                          ),
                        ),

                        const Spacer(),

                        _PaymentStatusPill(status: widget.order.status),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// UPDATE STATUS
                    const Text(
                      "UPDATE ORDER STATUS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<OrderStatus>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: OrderStatus.pending,
                          child: Text("Pending"),
                        ),

                        DropdownMenuItem(
                          value: OrderStatus.confirmed,
                          child: Text("Confirmed"),
                        ),

                        DropdownMenuItem(
                          value: OrderStatus.delivering,
                          child: Text("Delivering"),
                        ),

                        DropdownMenuItem(
                          value: OrderStatus.delivered,
                          child: Text("Delivered"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedStatus = v;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    /// ACTION TILES
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.receipt_long_outlined,
                            label: "Invoice",
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _ActionTile(
                            icon: Icons.chat_bubble_outline,
                            label: "WhatsApp",
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _ActionTile(
                            icon: Icons.call_outlined,
                            label: "Call",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            /// FOOTER BUTTON
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Update Order",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors.foreground,
        ),
      ),
    );
  }
}

class _CustomerInfoRow extends StatelessWidget {
  const _CustomerInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF8A74A7)),
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.title,
    required this.quantity,
    required this.amount,
  });

  final String title;
  final int quantity;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

              const SizedBox(height: 3),

              Text(
                "Qty: $quantity units",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        Text("₹$amount", style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final isComplete =
        status == OrderStatus.delivered || status == OrderStatus.confirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFFD1FAE5) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isComplete ? Icons.check_circle : Icons.timelapse, size: 16),

          const SizedBox(width: 4),

          Text(
            isComplete ? "Completed" : "Pending",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatusColors {
  const _StatusColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

_StatusColors _statusColors(OrderStatus status) {
  switch (status) {
    case OrderStatus.confirmed:
      return const _StatusColors(Color(0xFFEAE3F5), Color(0xFF4D0E7F));
    case OrderStatus.delivering:
      return const _StatusColors(Color(0xFFE7F3FF), Color(0xFF2A6FBE));
    case OrderStatus.delivered:
      return const _StatusColors(Color(0xFFDEF7EC), Color(0xFF0F5132));
    case OrderStatus.pending:
      return const _StatusColors(Color(0xFFFFF4E5), Color(0xFF8B5E00));
    case OrderStatus.all:
      return const _StatusColors(Color(0xFFEDE9F3), Color(0xFF4A3A59));
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

Widget _customerRow({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Color(0xFF8A74A7)),
      ),

      const SizedBox(width: 10),

      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ],
  );
}

Widget _paymentBadge(OrderStatus status) {
  bool done =
      status == OrderStatus.delivered || status == OrderStatus.confirmed;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: done ? Color(0xFFD1FAE5) : Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(done ? Icons.check_circle : Icons.timelapse, size: 16),

        const SizedBox(width: 4),

        Text(
          done ? "Completed" : "Pending",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

Widget _actionTile(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Color(0xFFEAEAEA)),
    ),
    child: Column(
      children: [
        Icon(icon, color: Colors.grey),

        const SizedBox(height: 4),

        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
