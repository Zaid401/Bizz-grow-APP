import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight repository to fetch dashboard aggregates from Supabase.
/// Gracefully falls back to zeros if tables/columns are missing so the UI keeps working.
class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DashboardData> fetch() async {
    final userId = _client.auth.currentUser?.id;
    final metaStoreId = _client.auth.currentUser?.userMetadata?['store_id']
        ?.toString();

    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = todayStart.subtract(const Duration(days: 29));
    final yearStart = DateTime.utc(now.year, 1, 1);

    // Pull store first to derive storeId for scoping downstream queries.
    final stores = await _select(
      table: 'stores',
      columns: '*',
      limit: 1,
      userId: userId,
      storeId: metaStoreId,
    );

    final storeId = stores.isNotEmpty
        ? (stores.first['id'] ?? stores.first['store_id'])?.toString()
        : metaStoreId;

    // Pull all columns to avoid "column X does not exist" errors; parse known keys with fallbacks.
    final todayOrders = await _select(
      table: 'orders',
      columns: '*',
      filter: (query) => _applyDateFilter(query, todayStart),
      userId: userId,
      storeId: storeId,
    );

    final weekOrders = await _select(
      table: 'orders',
      columns: '*',
      filter: (query) => _applyDateRangeFilter(query, weekStart, now),
      userId: userId,
      storeId: storeId,
    );

    final monthOrders = await _select(
      table: 'orders',
      columns: '*',
      filter: (query) => _applyDateRangeFilter(query, monthStart, now),
      userId: userId,
      storeId: storeId,
    );

    final yearOrders = await _select(
      table: 'orders',
      columns: '*',
      filter: (query) => _applyDateRangeFilter(query, yearStart, now),
      userId: userId,
      storeId: storeId,
    );

    final recentOrders = await _select(
      table: 'orders',
      columns: '*',
      order: const _Order('created_at', ascending: false),
      limit: 5,
      userId: userId,
      storeId: storeId,
    );

    final products = await _select(
      table: 'products',
      columns: 'id',
      userId: userId,
      storeId: storeId,
    );

    final customers = await _select(
      table: 'customers',
      columns: 'id',
      userId: userId,
      storeId: storeId,
    );

    final revenueToday = _sumOrders(todayOrders);

    final weekSales = _bucketByDay(weekOrders, weekStart, 7);
    final monthSales = _bucketByDay(monthOrders, monthStart, 30);
    final yearSales = _bucketByMonth(yearOrders, yearStart);

    final parsedRecentOrders = recentOrders
        .map(
          (row) => RecentOrder(
            id: row['id']?.toString() ?? '--',
            customerName:
                row['customer_name'] as String? ??
                row['name'] as String? ??
                'Customer',
            total: _asDouble(
              row['total'] ??
                  row['amount'] ??
                  row['grand_total'] ??
                  row['order_total'] ??
                  row['net_total'] ??
                  row['subtotal'] ??
                  row['total_amount'] ??
                  row['totalPrice'] ??
                  row['total_price'] ??
                  row['paid_amount'] ??
                  row['payment_amount'] ??
                  row['final_amount'],
            ),
            status: _normalizeStatus(
              row['payment_status'] as String? ?? row['status'] as String?,
            ),
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ?? now,
          ),
        )
        .toList();

    final storeInfo = stores.isEmpty
        ? null
        : (() {
            final row = stores.first;
            final cityOrAddress = _stringValue(row, const [
              'location',
              'address',
              'address_line1',
              'addressLine1',
              'street',
              'city',
              'locality',
              'area',
              'place',
              'full_address',
            ], '');
            final state = _stringValue(row, const [
              'state',
              'state_name',
              'province',
              'region',
              'district',
            ], '');
            final location = _joinNonEmpty([cityOrAddress, state], ', ');
            return StoreInfo(
              name: _stringValue(row, const [
                'name',
                'store_name',
                'title',
              ], 'My Store'),
              category: _stringValue(row, const [
                'category',
                'type',
                'segment',
              ], 'Retail'),
              mode: _stringValue(row, const [
                'mode',
                'delivery_mode',
                'service_mode',
              ], 'Shop + Delivery'),
              location: location.isNotEmpty ? location : 'Unknown',
              status: _stringValue(row, const [
                'status',
                'store_status',
              ], 'Active'),
            );
          })();

    return DashboardData(
      revenueToday: revenueToday,
      ordersToday: todayOrders.length,
      productsCount: products.length,
      customersCount: customers.length,
      recentOrders: parsedRecentOrders,
      storeInfo: storeInfo,
      weekSales: weekSales,
      monthSales: monthSales,
      yearSales: yearSales,
    );
  }

  Future<List<Map<String, dynamic>>> _select({
    required String table,
    required String columns,
    _Filter? filter,
    _Order? order,
    int? limit,
    String? userId,
    String? storeId,
  }) async {
    dynamic base = _client.from(table).select(columns);

    if (filter != null) {
      base = filter(base);
    }

    final storeColumns = storeId == null
        ? const <String>[]
        : const [
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

    dynamic applyOrderAndLimit(dynamic query) {
      if (order != null) {
        query = query.order(order.column, ascending: order.ascending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }
      return query;
    }

    // Require a store column when storeId is present; allow null when no store filter requested.
    final storeCandidates = storeColumns.isEmpty
        ? const [null]
        : [...storeColumns];

    // Allow skipping user filter if no matching user column exists, but only safe when store filter applies.
    final userCandidates = userColumns.isEmpty
        ? const [null]
        : [null, ...userColumns];

    for (final storeCol in storeCandidates) {
      for (final userCol in userCandidates) {
        dynamic query = base;
        // Enforce store scoping when storeId is provided; skip combinations without a store column.
        if (storeId != null && storeCol == null) {
          continue;
        }
        // If userId is provided but no user column, allow skipping user filter as long as store filter is applied.
        if (userId != null && userCol == null && storeId == null) {
          continue;
        }
        if (storeCol != null && storeId != null) {
          query = query.eq(storeCol, storeId);
        }
        if (userCol != null && userId != null) {
          query = query.eq(userCol, userId);
        }

        query = applyOrderAndLimit(query);

        try {
          final response = await query;
          return (response as List<dynamic>).cast<Map<String, dynamic>>();
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            // Missing column; try next candidate.
            continue;
          }
          rethrow;
        }
      }
    }

    // If store filtering was requested but no store column matched, return empty to avoid leaking data.
    if (storeId != null) {
      return <Map<String, dynamic>>[];
    }

    // If only user filtering was requested and no column matched, return empty to avoid leaking data.
    if (userId != null) {
      return <Map<String, dynamic>>[];
    }

    // Final fallback: no optional filters expected.
    final fallback = applyOrderAndLimit(base);
    final response = await fallback;
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Apply a date filter for "today" using common timestamp column names.
  dynamic _applyDateFilter(dynamic query, DateTime start) {
    final iso = start.toIso8601String();
    final candidates = [
      'created_at',
      'createdAt',
      'order_date',
      'placed_at',
      'date',
      'timestamp',
    ];
    for (final col in candidates) {
      try {
        return query.gte(col, iso);
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          continue; // missing column; try next
        }
        rethrow;
      }
    }
    return query; // no date filter applied
  }

  /// Apply a date range filter using common timestamp columns.
  dynamic _applyDateRangeFilter(dynamic query, DateTime start, DateTime end) {
    final isoStart = start.toIso8601String();
    final isoEnd = end.toIso8601String();
    final candidates = [
      'created_at',
      'createdAt',
      'order_date',
      'placed_at',
      'date',
      'timestamp',
    ];

    for (final col in candidates) {
      try {
        return query.gte(col, isoStart).lte(col, isoEnd);
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          continue; // missing column; try next
        }
        rethrow;
      }
    }

    return query; // no range filter applied
  }

  double _sumOrders(List<Map<String, dynamic>> orders) {
    return orders.fold<double>(0, (sum, row) => sum + _extractTotal(row));
  }

  double _extractTotal(Map<String, dynamic> row) {
    final totalValue =
        row['total'] ??
        row['amount'] ??
        row['grand_total'] ??
        row['order_total'] ??
        row['net_total'] ??
        row['subtotal'] ??
        row['total_amount'] ??
        row['totalPrice'] ??
        row['total_price'] ??
        row['paid_amount'] ??
        row['payment_amount'] ??
        row['final_amount'];
    return _asDouble(totalValue);
  }

  DateTime _extractTimestamp(Map<String, dynamic> row, DateTime fallback) {
    const fields = [
      'created_at',
      'createdAt',
      'order_date',
      'placed_at',
      'date',
      'timestamp',
    ];

    for (final key in fields) {
      final value = row[key];
      if (value is DateTime) return value.toUtc();
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toUtc();
      }
    }

    return fallback;
  }

  List<SalesPoint> _bucketByDay(
    List<Map<String, dynamic>> rows,
    DateTime start,
    int days,
  ) {
    final end = start.add(Duration(days: days));
    final totals = List<double>.filled(days, 0);

    for (final row in rows) {
      final createdAt = _extractTimestamp(row, start);
      if (createdAt.isBefore(start) || createdAt.isAfter(end)) continue;
      final idx = createdAt.difference(start).inDays;
      if (idx >= 0 && idx < days) {
        totals[idx] += _extractTotal(row);
      }
    }

    return List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      return SalesPoint(
        date: date,
        value: totals[i],
        label: _weekdayLabel(date.weekday),
      );
    });
  }

  List<SalesPoint> _bucketByMonth(
    List<Map<String, dynamic>> rows,
    DateTime yearStart,
  ) {
    final totals = List<double>.filled(12, 0);
    final yearEnd = DateTime.utc(yearStart.year + 1, 1, 1);

    for (final row in rows) {
      final createdAt = _extractTimestamp(row, yearStart);
      if (createdAt.isBefore(yearStart) || createdAt.isAfter(yearEnd)) {
        continue;
      }
      final monthIndex = createdAt.month - 1;
      totals[monthIndex] += _extractTotal(row);
    }

    return List.generate(12, (i) {
      final date = DateTime.utc(yearStart.year, i + 1, 1);
      return SalesPoint(
        date: date,
        value: totals[i],
        label: _monthLabel(i + 1),
      );
    });
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _weekdayLabel(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekday < 1 || weekday > 7) return '--';
    // Align to Thu start like reference by rotating? keep natural order.
    return names[weekday - 1];
  }

  String _monthLabel(int month) {
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
    if (month < 1 || month > 12) return '--';
    return months[month - 1];
  }

  String _normalizeStatus(String? status) {
    final normalized = (status ?? 'pending').toLowerCase();
    if (normalized.contains('success') ||
        normalized.contains('paid') ||
        normalized.contains('complete')) {
      return 'completed';
    }
    if (normalized.contains('cancel')) return 'cancelled';
    if (normalized.contains('fail')) return 'failed';
    return 'pending';
  }

  String _stringValue(
    Map<String, dynamic> row,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  String _joinNonEmpty(List<String> parts, String separator) {
    return parts.where((p) => p.trim().isNotEmpty).join(separator).trim();
  }
}

class DashboardData {
  const DashboardData({
    required this.revenueToday,
    required this.ordersToday,
    required this.productsCount,
    required this.customersCount,
    required this.recentOrders,
    required this.storeInfo,
    required this.weekSales,
    required this.monthSales,
    required this.yearSales,
  });

  final double revenueToday;
  final int ordersToday;
  final int productsCount;
  final int customersCount;
  final List<RecentOrder> recentOrders;
  final StoreInfo? storeInfo;
  final List<SalesPoint> weekSales;
  final List<SalesPoint> monthSales;
  final List<SalesPoint> yearSales;
}

class SalesPoint {
  const SalesPoint({
    required this.date,
    required this.value,
    required this.label,
  });

  final DateTime date;
  final double value;
  final String label;
}

class RecentOrder {
  const RecentOrder({
    required this.id,
    required this.customerName,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final double total;
  final String status;
  final DateTime createdAt;
}

class StoreInfo {
  const StoreInfo({
    required this.name,
    required this.category,
    required this.mode,
    required this.location,
    required this.status,
  });

  final String name;
  final String category;
  final String mode;
  final String location;
  final String status;
}

typedef _Filter = dynamic Function(dynamic query);

class _Order {
  const _Order(this.column, {required this.ascending});

  final String column;
  final bool ascending;
}
