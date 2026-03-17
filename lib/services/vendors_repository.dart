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
    required this.paidAmount,
    required this.remainingAmount,
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
  final double paidAmount;
  final double remainingAmount;
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

  Future<void> updateVendor({
    required String vendorId,
    required String name,
    String? phone,
    String? email,
    String? address,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'is_active': isActive,
      'phone': phone?.trim().isNotEmpty == true ? phone?.trim() : null,
      'email': email?.trim().isNotEmpty == true ? email?.trim() : null,
      'address': address?.trim().isNotEmpty == true ? address?.trim() : null,
    };

    const idColumns = ['id', 'vendor_id'];
    var updated = false;
    for (final idCol in idColumns) {
      try {
        await _client.from('vendors').update(payload).eq(idCol, vendorId);
        updated = true;
        break;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }

    if (!updated) {
      throw Exception('Unable to update vendor: id column not found.');
    }
  }

  Future<void> deleteVendor({required String vendorId}) async {
    const idColumns = ['id', 'vendor_id'];
    var deleted = false;
    for (final idCol in idColumns) {
      try {
        await _client.from('vendors').delete().eq(idCol, vendorId);
        deleted = true;
        break;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }

    if (!deleted) {
      throw Exception('Unable to delete vendor: id column not found.');
    }
  }

  Future<void> createPurchase({
    required String vendorId,
    String? productId,
    required String productName,
    required double quantity,
    required double unitPrice,
    required double totalAmount,
    required String paymentStatus,
    double? paidAmount,
    double? remainingAmount,
    DateTime? purchaseDate,
    String? note,
    String? storeId,
  }) async {
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store first.',
      );
    }

    final basePayload = <String, dynamic>{
      'store_id': targetStoreId,
      'vendor_id': vendorId,
      if (productId != null && productId.trim().isNotEmpty)
        'product_id': productId.trim(),
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'payment_status': paymentStatus,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (remainingAmount != null) 'remaining_amount': remainingAmount,
      if (purchaseDate != null) 'purchase_date': purchaseDate.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    await _client.from('vendor_purchases').insert(basePayload);
  }

  Future<void> updatePurchasePayment({
    required String purchaseId,
    required double paidAmount,
    required double remainingAmount,
    required String paymentStatus,
    double? paymentAmount,
    String? paymentMethod,
    String? comment,
    String? storeId,
  }) async {
    const idColumns = ['id', 'purchase_id'];
    var updated = false;
    final payload = <String, dynamic>{
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'payment_status': paymentStatus,
    };

    for (final idCol in idColumns) {
      try {
        await _client
            .from('vendor_purchases')
            .update(payload)
            .eq(idCol, purchaseId);
        updated = true;
        break;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }

    if (!updated) {
      throw Exception(
        'Unable to update payment: purchase id column not found.',
      );
    }

    if (paymentAmount != null && paymentAmount > 0) {
      final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);
      if (targetStoreId == null || targetStoreId.isEmpty) {
        throw Exception(
          'No store is linked to the current user. Please link a store first.',
        );
      }
      final normalizedMethod = _normalizePaymentMethod(paymentMethod) ?? 'cash';
      final paymentPayload = <String, dynamic>{
        'purchase_id': purchaseId,
        'store_id': targetStoreId,
        'amount': paymentAmount,
        'payment_method': normalizedMethod,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      };
      await _client.from('vendor_payments').insert(paymentPayload);
    }
  }

  String? _normalizePaymentMethod(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (trimmed == 'cash') return 'cash';
    if (trimmed == 'upi') return 'upi';
    if (trimmed == 'card') return 'card';
    if (trimmed == 'bank transfer' || trimmed == 'bank_transfer') {
      return 'bank_transfer';
    }
    return trimmed.replaceAll(' ', '_');
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
      paidAmount: parseNum(row['paid_amount'] ?? row['paid'] ?? 0),
      remainingAmount: parseNum(
        row['remaining_amount'] ?? row['balance'] ?? row['due'] ?? 0,
      ),
      purchaseDate: parseDate(
        row['purchase_date'] ?? row['date'] ?? row['created_at'],
      ),
      paymentStatus: (row['payment_status'] ?? row['status'] ?? 'unpaid')
          .toString(),
    );
  }
}
