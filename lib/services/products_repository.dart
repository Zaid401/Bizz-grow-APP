import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.status,
    required this.categoryTag,
    required this.isLowStock,
    required this.isOutOfStock,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String imageUrl;
  final String status;
  final String categoryTag;
  final bool isLowStock;
  final bool isOutOfStock;
}

class ProductsRepository {
  ProductsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ProductItem>> fetchProducts({String? storeId}) async {
    final userId = _client.auth.currentUser?.id;
    final targetStoreId = await _resolveStoreId(storeIdOverride: storeId);

    // Build base query on products table.
    final base = _client.from('products').select('*');

    // Common column spellings for store and user scoping.
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

    if (targetStoreId != null && targetStoreId.isNotEmpty) {
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
            if (e.code == '42703') continue; // column missing
            rethrow;
          }
        }
      }
    }

    // Fallback: no store scoping found; return all rows.
    final res = await base;
    final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(_toProduct).toList();
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

    // Try to fetch store by user binding using common spellings.
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
        if (e.code == '42703') continue;
        rethrow;
      }
    }
    return null;
  }

  ProductItem _toProduct(Map<String, dynamic> row) {
    final id = (row['id'] ?? row['product_id'] ?? '').toString();
    final name =
        (row['name'] ?? row['title'] ?? row['product_name'] ?? 'Product')
            .toString();
    final category = (row['category'] ?? row['type'] ?? row['segment'] ?? '')
        .toString();
    final categoryTag = (row['category_tag'] ?? row['tag'] ?? category)
        .toString();
    final priceRaw =
        row['price'] ?? row['mrp'] ?? row['sale_price'] ?? row['amount'] ?? 0;
    final stockRaw = row['stock'] ?? row['quantity'] ?? row['qty'] ?? 0;
    final status = (row['status'] ?? row['state'] ?? 'active').toString();
    final image =
        (row['image'] ?? row['image_url'] ?? row['thumbnail'] ?? row['photo'])
            ?.toString() ??
        '';

    final price = _asDouble(priceRaw);
    final stock = _asInt(stockRaw);

    final lowThresholdRaw = row['low_stock_threshold'] ?? row['min_stock'] ?? 5;
    final lowThreshold = lowThresholdRaw is num
        ? lowThresholdRaw.toInt()
        : int.tryParse(lowThresholdRaw.toString()) ?? 5;

    final isOutOfStock = stock <= 0 || status.toLowerCase() == 'out_of_stock';
    final isLowStock = !isOutOfStock && stock <= lowThreshold;

    return ProductItem(
      id: id,
      name: name,
      category: category,
      price: price,
      stock: stock,
      imageUrl: image,
      status: status,
      categoryTag: categoryTag,
      isLowStock: isLowStock,
      isOutOfStock: isOutOfStock,
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

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
