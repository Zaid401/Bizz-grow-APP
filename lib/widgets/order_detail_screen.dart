import 'package:flutter/material.dart';
import 'package:bizz_grow/models/order_types.dart';
import 'package:bizz_grow/loading/skeleton_order_detail.dart';
import '../services/orders_repository.dart';

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
  static const pink = Color(0xFFDB2777);
  static const pinkSoft = Color(0xFFFCE7F3);
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
}

// ══════════════════════════════════════════════════════════════════════════════
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final OrderRecord order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late OrderStatus _selectedStatus;
  final OrdersRepository _ordersRepository = OrdersRepository();
  OrderRecord? _order;
  OrderPaymentSummary? _paymentSummary;
  bool _loading = true;
  bool _savingStatus = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadOrder();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await _ordersRepository.fetchOrderById(widget.order.id);
      final base = latest ?? widget.order;
      final summary = await _ordersRepository.fetchPaymentSummaryForOrder(
        base.id,
      );
      final paid = summary?.paidAmount ?? (base.paidAmount ?? 0);
      final remaining =
          summary?.remainingAmount ??
          (base.remainingAmount ?? (base.amount - paid));
      final amount = summary != null && summary.totalAmount > 0
          ? summary.totalAmount
          : base.amount;
      final merged = _mergeOrder(
        base,
        invoiceId: summary?.invoiceId,
        amount: amount,
        paidAmount: paid,
        remainingAmount: remaining < 0 ? 0 : remaining,
      );
      if (!mounted) return;
      setState(() {
        _order = merged;
        _paymentSummary = summary;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  OrderRecord _mergeOrder(
    OrderRecord base, {
    String? invoiceId,
    double? amount,
    double? paidAmount,
    double? remainingAmount,
  }) {
    return OrderRecord(
      id: base.id,
      invoiceId: invoiceId ?? base.invoiceId,
      customer: base.customer,
      phone: base.phone,
      items: base.items,
      amount: amount ?? base.amount,
      paidAmount: paidAmount ?? base.paidAmount,
      remainingAmount: remainingAmount ?? base.remainingAmount,
      itemLines: base.itemLines,
      channel: base.channel,
      status: base.status,
      paymentStatus: base.paymentStatus,
      paymentMethod: base.paymentMethod,
      createdAt: base.createdAt,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final order = _order ?? widget.order;
    final lineItems = order.itemLines ?? const [];
    final statusStyle = _statusStyle(order.status);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Scrollable content ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: _loading
                  ? const OrderDetailSkeleton()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(order),
                            const SizedBox(height: 14),

                            // Loading / error strip
                            if (_loading)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: const LinearProgressIndicator(
                                  minHeight: 3,
                                  color: _C.accentLight,
                                  backgroundColor: _C.accentSoft,
                                ),
                              ),
                            if (_error != null) _buildErrorBanner(_error!),
                            const SizedBox(height: 4),

                            // Status strip
                            _StatusStrip(
                              status: order.status,
                              style: statusStyle,
                            ),
                            const SizedBox(height: 20),

                            // Order meta chips
                            _buildMetaChips(order),
                            const SizedBox(height: 22),

                            // Customer
                            _sectionLabel(
                              Icons.person_rounded,
                              'Customer Details',
                            ),
                            const SizedBox(height: 10),
                            _buildCustomerCard(order),
                            const SizedBox(height: 22),

                            // Order items
                            _sectionLabel(
                              Icons.inventory_2_rounded,
                              'Order Items',
                            ),
                            const SizedBox(height: 10),
                            _buildItemsCard(order, lineItems),
                            const SizedBox(height: 22),

                            // Payment
                            _sectionLabel(
                              Icons.account_balance_wallet_rounded,
                              'Payment Information',
                            ),
                            const SizedBox(height: 10),
                            _PaymentInfoCard(
                              order: order,
                              onRecordPayment: () => _showPaymentDetails(order),
                            ),
                            const SizedBox(height: 22),

                            // Status update
                            _sectionLabel(
                              Icons.update_rounded,
                              'Update Order Status',
                            ),
                            const SizedBox(height: 10),
                            _buildStatusDropdown(),
                            const SizedBox(height: 22),

                            // Quick actions
                            _sectionLabel(Icons.bolt_rounded, 'Quick Actions'),
                            const SizedBox(height: 10),
                            _buildActionRow(),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
            ),

            // ── Sticky footer ──────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFooterButton(order.id),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(OrderRecord order) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _C.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '#${widget.order.id.length > 12 ? widget.order.id.substring(0, 12) + "…" : widget.order.id}',
                style: const TextStyle(fontSize: 11, color: _C.textSecondary),
              ),
            ],
          ),
        ),
        // Time ago badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _timeAgo(order.createdAt),
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

  // ── Meta chips ─────────────────────────────────────────────────────────────
  Widget _buildMetaChips(OrderRecord order) {
    final isOnline = order.channel == OrderChannel.online;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          isOnline ? Icons.language_rounded : Icons.storefront_rounded,
          isOnline ? 'Online' : 'Walk-in',
          isOnline ? _C.blue : _C.green,
          isOnline ? _C.blueSoft : _C.greenSoft,
        ),
        _chip(
          Icons.payment_rounded,
          order.paymentMethod,
          _C.accentLight,
          _C.accentSoft,
        ),
        _chip(
          Icons.receipt_rounded,
          order.invoiceId != null && order.invoiceId!.isNotEmpty
              ? 'INV ${order.invoiceId!.length > 8 ? order.invoiceId!.substring(0, 8) + "…" : order.invoiceId}'
              : 'No Invoice',
          _C.textSecondary,
          _C.bg,
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color tint, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: tint.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: tint),
        const SizedBox(width: 5),
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

  // ── Customer card ──────────────────────────────────────────────────────────
  Widget _buildCustomerCard(OrderRecord order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _customerRow(
            Icons.person_rounded,
            order.customer,
            'Primary Customer',
          ),
          if (order.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: _C.divider),
            const SizedBox(height: 12),
            _customerRow(Icons.phone_rounded, order.phone, 'Phone Number'),
          ],
        ],
      ),
    );
  }

  Widget _customerRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _C.accentLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Items card ─────────────────────────────────────────────────────────────
  Widget _buildItemsCard(OrderRecord order, List<OrderLineItem> lineItems) {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Product',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _C.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _C.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 60),
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _C.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          if (lineItems.isEmpty)
            _itemRow('Items in order', order.items, order.amount)
          else
            ...lineItems.asMap().entries.map((e) {
              final isLast = e.key == lineItems.length - 1;
              return _lineRow(e.value, isLast: isLast);
            }),
          // Total row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: _C.accentSoft,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '₹${_money(order.amount)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.accent,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String title, int qty, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.divider, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _C.textPrimary,
              ),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: _C.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 60),
          Text(
            '₹${_money(amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(OrderLineItem item, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.divider, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '×${item.quantity}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.accentLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '₹${_money(item.price)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status dropdown ────────────────────────────────────────────────────────
  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<OrderStatus>(
          value: _selectedStatus,
          decoration: const InputDecoration(border: InputBorder.none),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _C.textSecondary,
          ),
          style: const TextStyle(
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            DropdownMenuItem(
              value: OrderStatus.pending,
              child: Text('Pending'),
            ),
            DropdownMenuItem(
              value: OrderStatus.confirmed,
              child: Text('Confirmed'),
            ),
            DropdownMenuItem(
              value: OrderStatus.delivering,
              child: Text('Delivering'),
            ),
            DropdownMenuItem(
              value: OrderStatus.delivered,
              child: Text('Delivered'),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedStatus = v);
          },
        ),
      ),
    );
  }

  // ── Action row ─────────────────────────────────────────────────────────────
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.receipt_long_rounded,
            label: 'Invoice',
            tint: _C.accentLight,
            soft: _C.accentSoft,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            tint: _C.green,
            soft: _C.greenSoft,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.phone_rounded,
            label: 'Call',
            tint: _C.blue,
            soft: _C.blueSoft,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // ── Footer button ──────────────────────────────────────────────────────────
  Widget _buildFooterButton(String orderId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
      child: GestureDetector(
        onTap: _savingStatus ? null : () => _updateOrderStatus(orderId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: _savingStatus
                ? null
                : const LinearGradient(
                    colors: [_C.accentLight, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _savingStatus ? _C.divider : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _savingStatus
                ? []
                : [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: _savingStatus
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _C.accentLight,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Update Order Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  BoxDecoration _cardDeco() => BoxDecoration(
    color: _C.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _C.divider),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _sectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _C.accentLight, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.divider, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _C.amberSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.amber.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: _C.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg, style: TextStyle(fontSize: 12, color: _C.amber)),
        ),
      ],
    ),
  );

  // ── Dialogs ────────────────────────────────────────────────────────────────
  Future<void> _showPaymentDetails(OrderRecord order) async {
    final summary = _paymentSummary;
    final invoiceId = summary?.invoiceId ?? order.invoiceId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentDetailsSheet(
        order: order,
        summary: summary,
        loadHistory: () =>
            _ordersRepository.fetchPaymentHistoryForInvoice(invoiceId),
        onSubmitPayment: (amount, comment) => _ordersRepository.addPayment(
          invoiceId: invoiceId,
          amount: amount,
          comment: comment,
        ),
        onPaymentRecorded: _loadOrder,
      ),
    );
    if (mounted) await _loadOrder();
  }

  Future<void> _updateOrderStatus(String orderId) async {
    // Modern confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.update_rounded,
                  color: _C.accentLight,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Update',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set order status to\n"${_statusLabel(_selectedStatus)}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _C.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _C.bg,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _C.divider),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                        child: const Center(
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
    if (confirmed != true) return;

    setState(() => _savingStatus = true);
    try {
      await _ordersRepository.updateOrderStatus(
        orderId: orderId,
        status: _selectedStatus,
      );
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      // Success snackbar instead of dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('Status updated to ${_statusLabel(_selectedStatus)}'),
            ],
          ),
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }
}

// ── Status Strip ───────────────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.style});
  final OrderStatus status;
  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: style.softBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: style.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: style.color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Info Card ──────────────────────────────────────────────────────────
class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({required this.order, required this.onRecordPayment});
  final OrderRecord order;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final paid = order.paidAmount ?? 0;
    final remaining = _remainingValue(order);
    final isPaid = remaining <= 0;
    final label = isPaid ? 'Paid' : 'Partial';
    final pillColor = isPaid ? _C.green : _C.amber;
    final pillSoft = isPaid ? _C.greenSoft : _C.amberSoft;
    final pillIcon = isPaid
        ? Icons.check_circle_rounded
        : Icons.hourglass_top_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Payment Status',
                style: TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pillSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pillColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pillIcon, size: 12, color: pillColor),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pillColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Amount tiles
          Row(
            children: [
              _AmountTile(
                label: 'Total',
                value: order.amount,
                tint: _C.textPrimary,
                soft: _C.bg,
              ),
              const SizedBox(width: 8),
              _AmountTile(
                label: 'Paid',
                value: paid,
                tint: _C.green,
                soft: _C.greenSoft,
              ),
              const SizedBox(width: 8),
              _AmountTile(
                label: 'Remaining',
                value: remaining,
                tint: _C.red,
                soft: _C.redSoft,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Record payment button
          GestureDetector(
            onTap: onRecordPayment,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _C.amberSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _C.amber.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_rounded, color: _C.amber, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Record Payment',
                    style: TextStyle(
                      color: _C.amber,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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

// ── Amount Tile ────────────────────────────────────────────────────────────────
class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.tint,
    required this.soft,
  });
  final String label;
  final double value;
  final Color tint, soft;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _C.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_money(value)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Action Card ────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.tint,
    required this.soft,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color tint, soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Payment Details Sheet ──────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentDetailsSheet extends StatefulWidget {
  const _PaymentDetailsSheet({
    required this.order,
    required this.summary,
    required this.loadHistory,
    required this.onSubmitPayment,
    required this.onPaymentRecorded,
  });
  final OrderRecord order;
  final OrderPaymentSummary? summary;
  final Future<List<PaymentEntry>> Function() loadHistory;
  final Future<void> Function(double amount, String? comment) onSubmitPayment;
  final Future<void> Function() onPaymentRecorded;

  @override
  State<_PaymentDetailsSheet> createState() => _PaymentDetailsSheetState();
}

class _PaymentDetailsSheetState extends State<_PaymentDetailsSheet> {
  late Future<List<PaymentEntry>> _historyFuture;
  late double _paid;
  late double _remaining;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.loadHistory();
    _paid = widget.order.paidAmount ?? 0;
    _remaining = _remainingValue(widget.order);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final paid = _paid;
    final isPaid = remaining <= 0;
    final label = isPaid ? 'Paid' : 'Partial';
    final pillColor = isPaid ? _C.green : _C.amber;
    final pillSoft = isPaid ? _C.greenSoft : _C.amberSoft;
    final invoiceLabel =
        widget.summary?.invoiceNumber ?? widget.summary?.invoiceId;
    final displayInv = (invoiceLabel == null || invoiceLabel.isEmpty)
        ? widget.order.invoiceId ?? '—'
        : invoiceLabel;
    final comment = widget.summary?.paymentComment;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
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
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'INV $displayInv · ${widget.order.customer}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
            const SizedBox(height: 16),
            // Summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Payment Status',
                        style: TextStyle(fontSize: 12, color: _C.textSecondary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: pillSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: pillColor.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 12,
                              color: pillColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pillColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AmountTile(
                        label: 'Total Amount',
                        value: widget.order.amount,
                        tint: _C.textPrimary,
                        soft: _C.surface,
                      ),
                      const SizedBox(width: 8),
                      _AmountTile(
                        label: 'Paid',
                        value: paid,
                        tint: _C.green,
                        soft: _C.greenSoft,
                      ),
                      const SizedBox(width: 8),
                      _AmountTile(
                        label: 'Remaining',
                        value: remaining,
                        tint: _C.red,
                        soft: _C.redSoft,
                      ),
                    ],
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.comment_rounded,
                            size: 14,
                            color: _C.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comment,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment History',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PaymentEntry>>(
              future: _historyFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: _C.accentLight),
                    ),
                  );
                }
                final entries = snapshot.data ?? const [];
                if (entries.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: _C.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'No payment history yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: entries
                      .asMap()
                      .entries
                      .map(
                        (e) =>
                            _PaymentHistoryTile(index: e.key, entry: e.value),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _saving
                  ? null
                  : () => _showRecordPaymentForm(context, remaining),
              child: Container(
                width: double.infinity,
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
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Record New Payment',
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
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentForm(BuildContext context, double remaining) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RecordPaymentSheet(maxAmount: remaining, onSubmit: _submitPayment),
    );
  }

  Future<void> _submitPayment(double amount, String? comment) async {
    setState(() => _saving = true);
    try {
      await widget.onSubmitPayment(amount, comment);
      if (!mounted) return;
      setState(() {
        _paid += amount;
        _remaining = (_remaining - amount).clamp(0, double.infinity);
        _historyFuture = widget.loadHistory();
      });
      await widget.onPaymentRecorded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Payment recorded successfully.'),
            ],
          ),
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to record payment: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Record Payment Sheet ───────────────────────────────────────────────────────
class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({required this.maxAmount, required this.onSubmit});
  final double maxAmount;
  final Future<void> Function(double amount, String? comment) onSubmit;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _C.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
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
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
            const SizedBox(height: 16),
            // Max amount hint
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
                    Icons.info_outline_rounded,
                    color: _C.red,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Maximum payable: ₹${_money(widget.maxAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _C.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _fLabel('Payment Amount (₹)', required: true),
            const SizedBox(height: 6),
            _field(
              _amountCtrl,
              'Enter amount',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              icon: Icons.currency_rupee_rounded,
              errorText: _errorText,
            ),
            const SizedBox(height: 12),
            _fLabel('Comment (Optional)'),
            const SizedBox(height: 6),
            _field(
              _commentCtrl,
              'Add a note about this payment',
              maxLines: 3,
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _submitting ? null : () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _C.divider),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _C.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submitting ? null : _handleSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
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
                                'Submit Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: 13,
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
  }

  Widget _fLabel(String text, {bool required = false}) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _C.textSecondary,
        ),
      ),
      if (required)
        const Text(
          ' *',
          style: TextStyle(
            color: _C.accent,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
    ],
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboard,
    int maxLines = 1,
    IconData? icon,
    String? errorText,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    maxLines: maxLines,
    style: const TextStyle(color: _C.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _C.textSecondary.withOpacity(0.5)),
      prefixIcon: icon != null
          ? Icon(icon, color: _C.textSecondary, size: 17)
          : null,
      errorText: errorText,
      filled: true,
      fillColor: _C.inputFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: icon != null ? 6 : 14,
        vertical: 12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.accentLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _C.red, width: 1.5),
      ),
    ),
  );

  Future<void> _handleSubmit() async {
    final raw = _amountCtrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Enter a valid amount.');
      return;
    }
    if (amount > widget.maxAmount) {
      setState(() => _errorText = 'Amount exceeds remaining balance.');
      return;
    }
    setState(() {
      _errorText = null;
      _submitting = true;
    });
    final comment = _commentCtrl.text.trim();
    try {
      await widget.onSubmit(amount, comment.isEmpty ? null : comment);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Payment History Tile ───────────────────────────────────────────────────────
class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.index, required this.entry});
  final int index;
  final PaymentEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = entry.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')} ${_monthLabel(date.month)} ${date.year}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
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
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: _C.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _C.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Payment ${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _C.accentLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${_money(entry.amount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.green,
                      ),
                    ),
                  ],
                ),
                if (entry.comment != null && entry.comment!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.comment!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _C.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateText,
                style: const TextStyle(fontSize: 10, color: _C.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                timeText,
                style: const TextStyle(fontSize: 10, color: _C.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data helpers ───────────────────────────────────────────────────────────────
class _StatusStyle {
  const _StatusStyle(this.color, this.softBg, this.icon);
  final Color color, softBg;
  final IconData icon;
}

_StatusStyle _statusStyle(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const _StatusStyle(
        _C.amber,
        _C.amberSoft,
        Icons.hourglass_top_rounded,
      );
    case OrderStatus.confirmed:
      return const _StatusStyle(
        _C.accentLight,
        _C.accentSoft,
        Icons.check_circle_rounded,
      );
    case OrderStatus.delivering:
      return const _StatusStyle(
        _C.blue,
        _C.blueSoft,
        Icons.local_shipping_rounded,
      );
    case OrderStatus.delivered:
      return const _StatusStyle(_C.green, _C.greenSoft, Icons.done_all_rounded);
    case OrderStatus.all:
      return const _StatusStyle(_C.textSecondary, _C.bg, Icons.list_rounded);
  }
}

double _remainingValue(OrderRecord order) {
  final raw = order.remainingAmount ?? 0;
  final paid = order.paidAmount ?? 0;
  final rem = raw > 0 ? raw : (order.amount - paid);
  return rem < 0 ? 0 : rem;
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
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

String _timeAgo(DateTime d) {
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

String _monthLabel(int m) {
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
  return m >= 1 && m <= 12 ? months[m - 1] : '';
}
