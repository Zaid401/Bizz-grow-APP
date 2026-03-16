import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorRecord {
  const VendorRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final bool isActive;
}

class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitQuantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.purchaseDate,
    required this.paymentStatus,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String productId;
  final String productName;
  final double quantity;
  final double unitQuantity;
  final double unitPrice;
  final double totalAmount;
  final DateTime purchaseDate;
  final String paymentStatus;
}

class VendorsRepository {
  VendorsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<VendorRecord>> fetchVendors({String? storeId}) async {
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

    final base = _client.from('vendors').select('*');

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
          return list.map(_toVendor).toList();
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            continue;
          }
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not find a store column on vendors to filter by store.',
    );
  }

  Future<List<PurchaseRecord>> fetchPurchases({String? storeId}) async {
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

    final base = _client.from('vendor_purchases').select('*');

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
          return list.map(_toPurchase).toList();
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            continue;
          }
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not find a store column on vendor_purchases to filter by store.',
    );
  }

  Future<void> createVendor({
    required String name,
    String? phone,
    String? email,
    String? address,
    bool isActive = true,
    String? storeId,
  }) async {
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store first.',
      );
    }

    final payload = <String, dynamic>{
      'store_id': targetStoreId,
      'name': name,
      'is_active': isActive,
    };
    if (phone != null && phone.trim().isNotEmpty) {
      payload['phone'] = phone.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      payload['address'] = address.trim();
    }

    await _client.from('vendors').insert(payload);
  }

  Future<void> createPurchase({
    required String vendorId,
    String? productId,
    required String productName,
    required double quantity,
    required double unitQuantity,
    required double unitPrice,
    required double totalAmount,
    required String paymentStatus,
    String? storeId,
  }) async {
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store first.',
      );
    }

    final payload = <String, dynamic>{
      'store_id': targetStoreId,
      'vendor_id': vendorId,
      if (productId != null && productId.trim().isNotEmpty)
        'product_id': productId.trim(),
      'product_name': productName,
      'quantity': quantity,
      'unit_quantity': unitQuantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'payment_status': paymentStatus,
    };

    await _client.from('vendor_purchases').insert(payload);
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

  VendorRecord _toVendor(Map<String, dynamic> row) {
    final id = (row['id'] ?? row['vendor_id'] ?? '').toString();
    final name = (row['name'] ?? row['vendor_name'] ?? 'Vendor').toString();
    final phone = (row['phone'] ?? row['phone_number'] ?? row['mobile'] ?? '')
        .toString();
    final email = (row['email'] ?? row['email_id'] ?? '').toString();
    final address = (row['address'] ?? row['location'] ?? row['city'] ?? '')
        .toString();
    final isActive = row['is_active'] ?? row['active'] ?? true;

    return VendorRecord(
      id: id.isEmpty ? '—' : id,
      name: name.isEmpty ? 'Vendor' : name,
      phone: phone,
      email: email,
      address: address,
      isActive: isActive is bool
          ? isActive
          : isActive.toString().toLowerCase() == 'true',
    );
  }

  PurchaseRecord _toPurchase(Map<String, dynamic> row) {
    final id = (row['id'] ?? row['purchase_id'] ?? '').toString();
    final vendorId = (row['vendor_id'] ?? row['vendorId'] ?? '').toString();
    final vendorName = (row['vendor_name'] ?? row['vendorName'] ?? 'Vendor')
        .toString();
    final productId = (row['product_id'] ?? row['productId'] ?? '').toString();
    final productName = (row['product_name'] ?? row['product'] ?? '')
        .toString();

    double parseNum(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
      final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
      return created ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return PurchaseRecord(
      id: id.isEmpty ? '—' : id,
      vendorId: vendorId,
      vendorName: vendorName.isEmpty ? 'Vendor' : vendorName,
      productId: productId,
      productName: productName,
      quantity: parseNum(row['quantity'] ?? row['qty']),
      unitQuantity: parseNum(row['unit_quantity'] ?? row['unit_qty'] ?? 1),
      unitPrice: parseNum(row['unit_price'] ?? row['price'] ?? row['rate']),
      totalAmount: parseNum(
        row['total_amount'] ?? row['amount'] ?? row['total'],
      ),
      purchaseDate: parseDate(
        row['purchase_date'] ?? row['date'] ?? row['created_at'],
      ),
      paymentStatus: (row['payment_status'] ?? row['status'] ?? 'unpaid')
          .toString(),
    );
  }
}
