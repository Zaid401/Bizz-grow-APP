import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DeliveryStatus { pending, inTransit, delivered, completed }

class DeliveryRecord {
  const DeliveryRecord({
    required this.id,
    required this.customer,
    required this.items,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.phone,
  });

  final String id;
  final String customer;
  final int items;
  final double amount;
  final DeliveryStatus status;
  final DateTime createdAt;
  final String? phone;
}

class DeliveryRepository {
  DeliveryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DeliveryRecord>> fetchDeliveries({String? storeId}) async {
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);

    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store or pass a storeId.',
      );
    }

    final tables = ['deliveries', 'delivery', 'orders', 'demo_requests'];

    for (int i = 0; i < tables.length; i++) {
      final table = tables[i];
      try {
        final rows = await _select(
          table: table,
          userId: userId,
          storeId: targetStoreId,
        );
        if (rows.isNotEmpty || i == tables.length - 1) {
          return rows.map(_toDelivery).toList();
        }
      } on PostgrestException catch (e) {
        final msg = e.message?.toLowerCase() ?? '';
        final missingTable =
            e.code == '42P01' ||
            e.code == 'PGRST205' ||
            msg.contains('could not find the table');

        if (missingTable) {
          // table does not exist; try next candidate
          continue;
        }

        rethrow;
      }
    }

    return <DeliveryRecord>[];
  }

  Future<List<Map<String, dynamic>>> _select({
    required String table,
    String? userId,
    required String storeId,
  }) async {
    dynamic base = _client.from(table).select('*');

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

    for (final storeCol in storeColumns) {
      for (final userCol
          in userColumns.isEmpty ? [null] : [null, ...userColumns]) {
        dynamic query = base.eq(storeCol, storeId);
        if (userCol != null && userId != null) {
          query = query.eq(userCol, userId);
        }

        try {
          final res = await query;
          final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
          return list;
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            continue; // missing column; try next spelling
          }
          rethrow;
        }
      }
    }

    // If we reach here, no store column matched. Return empty to avoid leaking data.
    return <Map<String, dynamic>>[];
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

  DeliveryRecord _toDelivery(Map<String, dynamic> row) {
    final id = (row['id'] ?? row['delivery_id'] ?? row['order_id'] ?? '')
        .toString();
    final customer =
        (row['customer_name'] ?? row['receiver_name'] ?? row['name'])
            ?.toString() ??
        'Customer';
    final phone = (row['phone'] ?? row['customer_phone'] ?? row['mobile'])
        ?.toString();
    final itemsRaw = row['items'] ?? row['packages'] ?? row['qty'] ?? 0;
    final amountRaw =
        row['amount'] ??
        row['total'] ??
        row['grand_total'] ??
        row['order_total'] ??
        row['total_amount'];
    final statusRaw =
        (row['delivery_status'] ?? row['status'] ?? row['order_status'] ?? '')
            .toString();
    final createdAtStr =
        (row['expected_date'] ?? row['created_at'] ?? row['date'])?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)?.toUtc()
        : null;

    return DeliveryRecord(
      id: id.isEmpty ? '—' : id,
      customer: customer.isEmpty ? 'Customer' : customer,
      items: _asInt(itemsRaw),
      amount: _asDouble(amountRaw),
      status: _normalizeStatus(statusRaw),
      createdAt: createdAt ?? DateTime.now().toUtc(),
      phone: (phone != null && phone.isNotEmpty) ? phone : null,
    );
  }

  DeliveryStatus _normalizeStatus(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('transit') || value.contains('ship')) {
      return DeliveryStatus.inTransit;
    }
    if (value.contains('deliver')) {
      return DeliveryStatus.delivered;
    }
    if (value.contains('complete')) {
      return DeliveryStatus.completed;
    }
    return DeliveryStatus.pending;
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
