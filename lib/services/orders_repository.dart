import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/orders.dart' show OrderChannel, OrderStatus;

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.customer,
    required this.items,
    required this.amount,
    required this.channel,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String customer;
  final int items;
  final double amount;
  final OrderChannel channel;
  final OrderStatus status;
  final String paymentMethod;
  final DateTime createdAt;
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
    final customer = (row['customer_name'] ?? row['name'] ?? 'Customer')
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

    return OrderRecord(
      id: id.isEmpty ? '—' : id,
      customer: customer.isEmpty ? 'Customer' : customer,
      items: _asInt(itemsRaw),
      amount: _asDouble(amountRaw),
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

  int _asInt(dynamic value) {
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
}
