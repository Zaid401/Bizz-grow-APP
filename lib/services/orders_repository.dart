import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bizz_grow/models/order_types.dart';

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.invoiceId,
    required this.customer,
    required this.phone,
    required this.items,
    required this.amount,
    this.paidAmount,
    this.remainingAmount,
    this.itemLines,
    required this.channel,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String invoiceId;
  final String customer;
  final String phone;
  final int items;
  final double amount;
  final double? paidAmount;
  final double? remainingAmount;
  final List<OrderLineItem>? itemLines;
  final OrderChannel channel;
  final OrderStatus status;
  final String paymentMethod;
  final DateTime createdAt;
}

class OrderLineItem {
  const OrderLineItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String name;
  final int quantity;
  final double price;
}

class OrderPaymentSummary {
  const OrderPaymentSummary({
    required this.invoiceId,
    this.invoiceNumber,
    this.paymentComment,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });

  final String invoiceId;
  final String? invoiceNumber;
  final String? paymentComment;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
}

class PaymentEntry {
  const PaymentEntry({
    required this.amount,
    required this.createdAt,
    this.comment,
  });

  final double amount;
  final DateTime createdAt;
  final String? comment;
}

class OrdersRepository {
  OrdersRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<OrderRecord>> fetchOrders({String? storeId}) async {
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);

    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store or pass a storeId.',
      );
    }

    const storeColumns = [
      'store_id',
      'storeId',
      'storeid',
      'store_uuid',
      'shop_id',
      'shopId',
      'shop_uuid',
      'store_uuid_fk',
      'store',
    ];

    final userColumns = userId == null
        ? const <String>[]
        : const [
            'user_id',
            'owner_id',
            'profile_id',
            'userId',
            'creator_id',
            'created_by',
            'seller_id',
          ];

    final base = _client.from('orders').select('*');

    for (final storeCol in storeColumns) {
      for (final userCol
          in userColumns.isEmpty ? [null] : [null, ...userColumns]) {
        dynamic query = base.eq(storeCol, targetStoreId);
        if (userCol != null && userId != null) {
          query = query.eq(userCol, userId);
        }

        try {
          final res = await query;
          final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
          return list.map(_toOrder).toList();
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            continue; // missing column; try next spelling
          }
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not find a store column on orders to filter by store.',
    );
  }

  Future<OrderRecord?> fetchOrderById(String orderId, {String? storeId}) async {
    if (orderId.trim().isEmpty) return null;
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) return null;

    const storeColumns = [
      'store_id',
      'storeId',
      'storeid',
      'store_uuid',
      'shop_id',
      'shopId',
      'shop_uuid',
      'store_uuid_fk',
      'store',
    ];
    const idColumns = ['id', 'order_id', 'orderId'];
    final userColumns = userId == null
        ? const <String>[]
        : const [
            'user_id',
            'owner_id',
            'profile_id',
            'userId',
            'creator_id',
            'created_by',
            'seller_id',
          ];

    final base = _client.from('orders').select('*');
    for (final idCol in idColumns) {
      for (final storeCol in storeColumns) {
        for (final userCol
            in userColumns.isEmpty ? [null] : [null, ...userColumns]) {
          dynamic query = base.eq(idCol, orderId).eq(storeCol, targetStoreId);
          if (userCol != null && userId != null) {
            query = query.eq(userCol, userId);
          }
          try {
            final res = await query.limit(1);
            final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
            if (list.isNotEmpty) return _toOrder(list.first);
          } on PostgrestException catch (e) {
            if (e.code == '42703') continue;
            rethrow;
          }
        }
      }
    }
    return null;
  }

  Future<OrderPaymentSummary?> fetchPaymentSummaryForOrder(
    String orderId, {
    String? storeId,
  }) async {
    if (orderId.trim().isEmpty) return null;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) return null;

    try {
      const selectOptions = [
        'id,order_id,total_amount,paid_amount,remaining_amount,invoice_number,payment_comment,payment_type,payment_status',
        'id,order_id,total_amount,paid_amount,remaining_amount,payment_comment,payment_type,payment_status',
        'id,order_id,total_amount,paid_amount,remaining_amount',
      ];

      List<dynamic>? invoiceRows;
      for (final columns in selectOptions) {
        try {
          invoiceRows = await _client
              .from('invoices')
              .select(columns)
              .eq('store_id', targetStoreId)
              .eq('order_id', orderId)
              .order('created_at', ascending: false)
              .limit(1);
          break;
        } on PostgrestException catch (e) {
          if (e.code == '42703') continue;
          rethrow;
        }
      }
      if (invoiceRows == null) return null;

      final invoiceList = (invoiceRows as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (invoiceList.isEmpty) return null;

      final invoice = invoiceList.first;
      final invoiceId = (invoice['id'] ?? '').toString();
      final invoiceNumber = (invoice['invoice_number'] ?? '').toString();
      final paymentComment = (invoice['payment_comment'] ?? '').toString();
      final total = _asDouble(invoice['total_amount']);
      final paidInvoice = _asDouble(invoice['paid_amount']);
      final remainingInvoice = _asDouble(invoice['remaining_amount']);

      double paid = paidInvoice;
      if (invoiceId.isNotEmpty) {
        final paymentRows = await _client
            .from('bill_payments')
            .select('amount')
            .eq('store_id', targetStoreId)
            .eq('invoice_id', invoiceId);
        final payments = (paymentRows as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final sum = payments.fold<double>(
          0,
          (s, row) => s + _asDouble(row['amount']),
        );
        if (sum > 0) paid = sum;
      }

      final remaining = remainingInvoice > 0
          ? remainingInvoice
          : (total - paid);
      final safeRemaining = remaining < 0 ? 0.0 : remaining;

      return OrderPaymentSummary(
        invoiceId: invoiceId.isEmpty ? orderId : invoiceId,
        invoiceNumber: invoiceNumber.isEmpty ? null : invoiceNumber,
        paymentComment: paymentComment.isEmpty ? null : paymentComment,
        totalAmount: total,
        paidAmount: paid,
        remainingAmount: safeRemaining,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42703') return null;
      rethrow;
    }
  }

  Future<List<PaymentEntry>> fetchPaymentHistoryForInvoice(
    String invoiceId, {
    String? storeId,
  }) async {
    if (invoiceId.trim().isEmpty) return const [];
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) return const [];

    const selectOptions = [
      'amount,created_at,comment',
      'amount,created_at,payment_comment',
      'amount,created_at,notes',
      'amount,created_at',
    ];

    List<dynamic>? rows;
    for (final columns in selectOptions) {
      try {
        rows = await _client
            .from('bill_payments')
            .select(columns)
            .eq('store_id', targetStoreId)
            .eq('invoice_id', invoiceId)
            .order('created_at', ascending: false);
        break;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }
    if (rows == null) return const [];

    final list = (rows as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return list.map((row) {
      final createdAtStr = row['created_at']?.toString();
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr)?.toLocal()
          : null;
      final comment = (row['comment'] ?? row['payment_comment'] ?? row['notes'])
          ?.toString();
      return PaymentEntry(
        amount: _asDouble(row['amount']),
        createdAt: createdAt ?? DateTime.now(),
        comment: comment?.isEmpty == true ? null : comment,
      );
    }).toList();
  }

  Future<double> fetchPaidAmountForOrder({
    required String orderId,
    String? invoiceId,
    String? storeId,
  }) async {
    if (orderId.trim().isEmpty && (invoiceId ?? '').trim().isEmpty) return 0;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) return 0;
    try {
      final targetId = (invoiceId != null && invoiceId.trim().isNotEmpty)
          ? invoiceId.trim()
          : orderId.trim();
      final rows = await _client
          .from('bill_payments')
          .select('amount')
          .eq('store_id', targetStoreId)
          .eq('invoice_id', targetId);
      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return list.fold<double>(0, (sum, row) => sum + _asDouble(row['amount']));
    } on PostgrestException catch (e) {
      if (e.code == '42703') return 0;
      rethrow;
    }
  }

  Future<void> addPayment({
    required String invoiceId,
    required double amount,
    String? comment,
    String? storeId,
  }) async {
    if (invoiceId.trim().isEmpty) {
      throw Exception('Missing invoice id for payment.');
    }
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception('Missing store id for payment.');
    }
    final payload = <String, dynamic>{
      'invoice_id': invoiceId,
      'store_id': targetStoreId,
      'amount': amount,
    };
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      payload['comment'] = trimmed;
    }
    await _client.from('bill_payments').insert(payload);

    try {
      final invoiceRows = await _client
          .from('invoices')
          .select('id,total_amount,paid_amount')
          .eq('id', invoiceId)
          .limit(1);
      final list = (invoiceRows as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isEmpty) return;
      final invoice = list.first;
      final total = _asDouble(invoice['total_amount']);
      final paid = _asDouble(invoice['paid_amount']);
      final newPaid = paid + amount;
      final remaining = total > 0 ? (total - newPaid) : 0;
      await _client
          .from('invoices')
          .update({
            'paid_amount': newPaid,
            'remaining_amount': remaining < 0 ? 0 : remaining,
          })
          .eq('id', invoiceId);
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        return; // missing invoice columns in this environment
      }
      rethrow;
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? storeId,
  }) async {
    if (orderId.trim().isEmpty) {
      throw Exception('Missing order id for status update.');
    }
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception('Missing store id for status update.');
    }

    const idColumns = ['id', 'order_id', 'orderId'];
    const storeColumns = [
      'store_id',
      'storeId',
      'storeid',
      'store_uuid',
      'shop_id',
      'shopId',
      'shop_uuid',
      'store_uuid_fk',
      'store',
    ];
    const statusColumns = ['status', 'order_status', 'payment_status'];
    final userColumns = userId == null
        ? const <String>[]
        : const [
            'user_id',
            'owner_id',
            'profile_id',
            'userId',
            'creator_id',
            'created_by',
            'seller_id',
          ];

    final statusValue = _statusValue(status);
    final base = _client.from('orders');

    for (final statusCol in statusColumns) {
      for (final idCol in idColumns) {
        for (final storeCol in storeColumns) {
          for (final userCol
              in userColumns.isEmpty ? [null] : [null, ...userColumns]) {
            try {
              dynamic query = base
                  .update({statusCol: statusValue})
                  .eq(idCol, orderId)
                  .eq(storeCol, targetStoreId);
              if (userCol != null && userId != null) {
                query = query.eq(userCol, userId);
              }
              final res = await query.select('id').limit(1);
              final list = (res as List)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              if (list.isNotEmpty) return;
            } on PostgrestException catch (e) {
              if (e.code == '42703') continue;
              rethrow;
            }
          }
        }
      }
    }

    throw Exception('Unable to update order status.');
  }

  Future<String?> _resolveStoreId({String? storeIdOverride}) async {
    if (storeIdOverride != null && storeIdOverride.isNotEmpty) {
      return storeIdOverride;
    }

    final metaStoreId = _client.auth.currentUser?.userMetadata?['store_id']
        ?.toString();
    if (metaStoreId != null && metaStoreId.isNotEmpty) {
      return metaStoreId;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    const userColumns = [
      'user_id',
      'owner_id',
      'profile_id',
      'userId',
      'creator_id',
      'created_by',
      'seller_id',
    ];

    for (final userCol in userColumns) {
      try {
        final res = await _client
            .from('stores')
            .select('*')
            .eq(userCol, userId)
            .limit(1);
        final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          final row = list.first;
          return (row['id'] ?? row['store_id'] ?? row['storeId'])?.toString();
        }
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          continue;
        }
        rethrow;
      }
    }

    return null;
  }

  OrderRecord _toOrder(Map<String, dynamic> row) {
    final id = (row['id'] ?? row['order_id'] ?? row['orderId'] ?? '')
        .toString();
    final invoiceId =
        (row['invoice_id'] ?? row['invoiceId'] ?? row['invoice'] ?? '')
            .toString();
    final customer = (row['customer_name'] ?? row['name'] ?? 'Customer')
        .toString();
    final phone =
        (row['customer_phone'] ??
                row['phone'] ??
                row['phone_number'] ??
                row['mobile'] ??
                row['mobile_no'] ??
                '')
            .toString();
    final itemsRaw =
        row['items'] ??
        row['items_count'] ??
        row['item_count'] ??
        row['itemsCount'] ??
        row['quantity'] ??
        row['qty'] ??
        0;
    final amountRaw =
        row['total'] ??
        row['amount'] ??
        row['grand_total'] ??
        row['order_total'] ??
        row['net_total'] ??
        row['subtotal'] ??
        row['total_amount'];
    final paidRaw = row['paid_amount'] ?? row['payment_amount'] ?? row['paid'];
    final remainingRaw =
        row['remaining_amount'] ?? row['due_amount'] ?? row['balance'];
    final channelRaw =
        (row['channel'] ??
                row['order_type'] ??
                row['type'] ??
                row['mode'] ??
                'online')
            .toString();
    final statusRaw =
        (row['status'] ??
                row['order_status'] ??
                row['payment_status'] ??
                'pending')
            .toString();
    final payment =
        (row['payment_method'] ??
                row['paymentMode'] ??
                row['payment_mode'] ??
                'COD')
            .toString();
    final createdAtStr = row['created_at']?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)?.toUtc()
        : null;

    final totalAmount = _asDouble(amountRaw);
    final paidAmount = _asDouble(paidRaw);
    final remainingAmount = _asDouble(remainingRaw);
    final itemLines = _parseItems(row['items']);
    final computedRemaining = remainingAmount > 0
        ? remainingAmount
        : (totalAmount - paidAmount);
    final safeRemaining = (computedRemaining < 0 ? 0 : computedRemaining)
        .toDouble();

    return OrderRecord(
      id: id.isEmpty ? '—' : id,
      invoiceId: invoiceId.isEmpty ? (id.isEmpty ? '—' : id) : invoiceId,
      customer: customer.isEmpty ? 'Customer' : customer,
      phone: phone.isEmpty ? '—' : phone,
      items: _asInt(itemsRaw),
      amount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: safeRemaining,
      itemLines: itemLines,
      channel: _mapChannel(channelRaw),
      status: _normalizeStatus(statusRaw),
      paymentMethod: payment.isEmpty ? 'COD' : payment,
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }

  OrderChannel _mapChannel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('walk') || v.contains('pickup') || v.contains('store')) {
      return OrderChannel.walkIn;
    }
    return OrderChannel.online;
  }

  OrderStatus _normalizeStatus(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('pending')) return OrderStatus.pending;
    if (value.contains('confirm')) return OrderStatus.confirmed;
    if (value.contains('deliver') && !value.contains('delivered')) {
      return OrderStatus.delivering;
    }
    if (value.contains('deliver')) return OrderStatus.delivered;
    return OrderStatus.all;
  }

  String _statusValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.delivering:
        return 'delivering';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.all:
        return 'pending';
    }
  }

  int _asInt(dynamic value) {
    if (value is List) {
      int total = 0;
      for (final item in value) {
        if (item is Map) {
          final qty = item['qty'] ?? item['quantity'] ?? item['count'];
          total += _asInt(qty);
        } else if (item is num) {
          total += item.toInt();
        }
      }
      return total;
    }
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  List<OrderLineItem> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    final items = <OrderLineItem>[];
    for (final entry in raw) {
      if (entry is Map) {
        final name =
            (entry['name'] ?? entry['title'] ?? entry['product'] ?? 'Item')
                .toString();
        final qty = _asInt(entry['qty'] ?? entry['quantity'] ?? entry['count']);
        final price = _asDouble(entry['price'] ?? entry['amount'] ?? 0);
        items.add(
          OrderLineItem(
            name: name.isEmpty ? 'Item' : name,
            quantity: qty <= 0 ? 1 : qty,
            price: price,
          ),
        );
      }
    }
    return items;
  }
}
