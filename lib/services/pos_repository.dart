import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
}

class PosRepository {
  PosRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PosProduct>> fetchProducts({String? storeId}) async {
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);

    if (targetStoreId == null || targetStoreId.isEmpty) {
      throw Exception(
        'No store is linked to the current user. Please link a store or pass a storeId.',
      );
    }

    // Common column spellings we can tolerate; we try each until one matches.
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

    final base = _client.from('products').select('*');

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
          return list.map(_toProduct).toList();
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            continue; // missing column; try next spelling
          }
          rethrow;
        }
      }
    }

    throw Exception(
      'Could not find a store column on products to filter by store.',
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

    // Try to fetch a store owned by this user using common column spellings.
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
          continue; // missing column; try next spelling
        }
        rethrow;
      }
    }

    return null;
  }

  PosProduct _toProduct(Map<String, dynamic> row) {
    final name =
        (row['name'] ?? row['title'] ?? row['product_name'] ?? 'Product')
            .toString();
    final priceRaw =
        row['price'] ?? row['mrp'] ?? row['sale_price'] ?? row['amount'] ?? 0;
    final image =
        (row['image'] ?? row['image_url'] ?? row['thumbnail'] ?? row['photo'])
            ?.toString() ??
        '';
    final category = (row['category'] ?? row['type'] ?? '').toString();

    return PosProduct(
      id: (row['id'] ?? row['product_id'] ?? '').toString(),
      name: name,
      price: _asDouble(priceRaw),
      imageUrl: image,
      category: category,
    );
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
