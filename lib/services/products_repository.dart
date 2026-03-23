import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.comparePrice,
    required this.stock,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.categoryTag,
    required this.isAvailable,
    required this.isLowStock,
    required this.isOutOfStock,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final double comparePrice;
  final int stock;
  final String description;
  final String imageUrl;
  final String status;
  final String categoryTag;
  final bool isAvailable;
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

  Future<void> updateStock({
    required String productId,
    required int stock,
  }) async {
    const idColumns = ['id', 'product_id'];
    const stockColumns = ['stock_quantity', 'stock', 'qty', 'quantity'];

    for (final stockCol in stockColumns) {
      for (final idCol in idColumns) {
        try {
          await _client
              .from('products')
              .update({stockCol: stock})
              .eq(idCol, productId);
          return;
        } on PostgrestException catch (e) {
          if (e.code == '42703') continue;
          rethrow;
        }
      }
    }

    throw Exception('Unable to update stock: column not found.');
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String category,
    required double price,
    required double comparePrice,
    required int stock,
    required String description,
    required bool isAvailable,
  }) async {
    final payload = {
      'name': name,
      'category': category,
      'price': price,
      'compare_price': comparePrice,
      'stock_quantity': stock,
      'description': description,
      'is_available': isAvailable,
    };

    const idColumns = ['id', 'product_id'];
    for (final idCol in idColumns) {
      try {
        await _client.from('products').update(payload).eq(idCol, productId);
        return;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }

    throw Exception('Unable to update product: column not found.');
  }

  Future<void> deleteProduct({required String productId}) async {
    const idColumns = ['id', 'product_id'];
    for (final idCol in idColumns) {
      try {
        await _client.from('products').delete().eq(idCol, productId);
        return;
      } on PostgrestException catch (e) {
        if (e.code == '42703') continue;
        rethrow;
      }
    }

    throw Exception('Unable to delete product: column not found.');
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
    final comparePriceRaw =
        row['compare_price'] ?? row['comparePrice'] ?? row['mrp'] ?? 0;
    final stockRaw =
        row['stock'] ??
        row['stock_quantity'] ??
        row['quantity'] ??
        row['qty'] ??
        0;
    final status = (row['status'] ?? row['state'] ?? 'active').toString();
    final description =
        (row['description'] ?? row['desc'] ?? row['details'] ?? '').toString();
    final image =
        (row['image'] ?? row['image_url'] ?? row['thumbnail'] ?? row['photo'])
            ?.toString() ??
        '';

    final price = _asDouble(priceRaw);
    final comparePrice = _asDouble(comparePriceRaw);
    final stock = _asInt(stockRaw);

    final lowThresholdRaw = row['low_stock_threshold'] ?? row['min_stock'] ?? 5;
    final lowThreshold = lowThresholdRaw is num
        ? lowThresholdRaw.toInt()
        : int.tryParse(lowThresholdRaw.toString()) ?? 5;

    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock <= lowThreshold;
    final isAvailable = _asBool(
      row['is_available'] ?? row['available'] ?? row['isAvailable'],
      fallback: status.toLowerCase() == 'active',
    );

    return ProductItem(
      id: id,
      name: name,
      category: category,
      price: price,
      comparePrice: comparePrice,
      stock: stock,
      description: description,
      imageUrl: image,
      status: status,
      categoryTag: categoryTag,
      isAvailable: isAvailable,
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

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lowered = value.toLowerCase().trim();
      if (['true', '1', 'yes', 'y', 'active', 'available'].contains(lowered))
        return true;
      if ([
        'false',
        '0',
        'no',
        'n',
        'inactive',
        'unavailable',
      ].contains(lowered))
        return false;
    }
    return fallback;
  }
}
