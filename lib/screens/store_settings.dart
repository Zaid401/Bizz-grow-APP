import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import 'Analytics.dart';
import 'customer.dart';
import 'dashboard.dart';
import 'delivery.dart';
import 'orders.dart';
import 'posBilling.dart';
import 'products.dart';
import 'slider.dart';
import 'notifications.dart';
import '../widgets/top_header.dart';
import '../widgets/shell_nav.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _storeNameController = TextEditingController(
    text: 'Lakshay Electronics',
  );
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = const [
    'Electronics',
    'Fashion',
    'Grocery',
    'Home',
    'Beauty',
    'Other',
  ];

  final List<String> _businessModes = const [
    'Shop Only (Walk-in)',
    'Online Only',
    'Online + Walk-in',
  ];

  StoreInfo? _storeInfo;
  String? _storeId;
  String? _storeIdColumn;
  String? _storeTable;
  Set<String> _storeColumns = <String>{};
  bool _loading = true;
  bool _saving = false;
  String _selectedCategory = 'Electronics';
  String _selectedBusinessMode = 'Shop Only (Walk-in)';
  String? _businessModeValue;
  bool _businessModeDirty = false;
  File? _logoFile;
  String? _logoUrl;
  bool _isActive = true;
  int _unreadNotifications = 0;

  // ── Light Theme Colours ───────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF4F0FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceElevated = Color(0xFFF9F6FE);
  static const Color _accent = Color(0xFF6D28D9);
  static const Color _accentLight = Color(0xFF8B5CF6);
  static const Color _accentSoft = Color(0xFFEDE9FE);
  static const Color _gold = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF1E1340);
  static const Color _textSecondary = Color(0xFF7C6F99);
  static const Color _divider = Color(0xFFE8E0F5);
  static const Color _inputFill = Color(0xFFFAF8FE);
  static const Color _green = Color(0xFF059669);
  static const Color _greenSoft = Color(0xFFD1FAE5);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _storeNameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dash = await _dashboardRepository.fetch();
      final storeRow = await _fetchStoreDetails();
      if (!mounted) return;
      final resolvedLogo = _resolveLogoUrl(dash.storeInfo?.logoUrl);
      setState(() {
        _storeInfo = dash.storeInfo;
        _logoUrl = resolvedLogo;
        if (storeRow != null) {
          _storeColumns = storeRow.keys.map((e) => e.toString()).toSet();
          final name = _stringValue(storeRow, const ['name', 'store_name']);
          if (name.isNotEmpty) _storeNameController.text = name;
          final category = _stringValue(storeRow, const ['category']);
          if (category.isNotEmpty && _categories.contains(category)) {
            _selectedCategory = category;
          }
          final mode = _stringValue(storeRow, const ['mode', 'business_mode']);
          if (mode.isNotEmpty) {
            final display = _businessModeFromDb(mode);
            if (display != null) {
              _selectedBusinessMode = display;
              _businessModeValue = mode;
            }
          }
          _businessModeDirty = false;
          _cityController.text = _stringValue(storeRow, const ['city']);
          _stateController.text = _stringValue(storeRow, const ['state']);
          _addressController.text = _stringValue(storeRow, const [
            'address',
            'full_address',
          ]);
          _isActive = _boolValue(storeRow['is_active'], fallback: true);
        }
      });
      await _loadUnreadNotifications();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeController.forward();
      }
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final user = _client.auth.currentUser;
      final userId = user?.id;
      final storeId = user?.userMetadata?['store_id']?.toString();

      List<Map<String, dynamic>> rows = const [];

      if (storeId != null && storeId.trim().isNotEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.or('store_id.eq.$storeId,user_id.eq.$userId');
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.eq('store_id', storeId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (rows.isEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.eq('user_id', userId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (!mounted) return;
      setState(() => _unreadNotifications = rows.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  Future<Map<String, dynamic>?> _fetchStoreDetails() async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    final metaStoreId = user?.userMetadata?['store_id']?.toString();
    final storeColumns = [
      'id',
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
    final userColumns = [
      'user_id',
      'owner_id',
      'profile_id',
      'userId',
      'creator_id',
      'created_by',
      'createdBy',
      'user_uuid',
      'owner_uuid',
      'profile_uuid',
    ];
    const tables = ['stores', 'Store'];
    for (final table in tables) {
      if (metaStoreId != null && metaStoreId.trim().isNotEmpty) {
        for (final column in storeColumns) {
          try {
            final result = await _client
                .from(table)
                .select('*')
                .eq(column, metaStoreId)
                .limit(1);
            if (result is List && result.isNotEmpty) {
              final row = Map<String, dynamic>.from(result.first);
              _captureStoreId(row, metaStoreId, column);
              _storeTable = table;
              return row;
            }
          } catch (_) {}
        }
      }
      if (userId != null) {
        for (final column in userColumns) {
          try {
            final result = await _client
                .from(table)
                .select('*')
                .eq(column, userId)
                .limit(1);
            if (result is List && result.isNotEmpty) {
              final row = Map<String, dynamic>.from(result.first);
              _captureStoreId(row, metaStoreId, null);
              _storeTable = table;
              return row;
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  void _captureStoreId(
    Map<String, dynamic> row,
    String? fallbackId,
    String? matchedColumn,
  ) {
    final idValue = row['id'] ?? row['store_id'] ?? fallbackId;
    _storeId = idValue?.toString();
    if (row.containsKey('id')) {
      _storeIdColumn = 'id';
    } else if (row.containsKey('store_id')) {
      _storeIdColumn = 'store_id';
    } else if (matchedColumn != null) {
      _storeIdColumn = matchedColumn;
    }
  }

  void _putIfPresent(
    Map<String, dynamic> payload,
    List<String> keys,
    Object? value,
  ) {
    for (final key in keys) {
      if (_storeColumns.contains(key)) {
        payload[key] = value;
        return;
      }
    }
  }

  String _stringValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  bool _boolValue(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final n = value.trim().toLowerCase();
      if (n.isEmpty) return fallback;
      return n == 'true' || n == '1' || n == 'yes';
    }
    return fallback;
  }

  String? _businessModeFromDb(String value) {
    switch (value) {
      case 'shop_only':
      case 'shop_only_walkin':
        return 'Shop Only (Walk-in)';
      case 'online_only':
        return 'Online Only';
      case 'online_walkin':
      case 'online_walk_in':
      case 'online_and_walkin':
      case 'online_and_walk_in':
      case 'online_plus_walkin':
        return 'Online + Walk-in';
    }

    if (_businessModes.contains(value)) {
      return value;
    }

    return null;
  }

  String? _businessModeToDb(String value) {
    switch (value) {
      case 'Shop Only (Walk-in)':
        return 'shop_only';
      case 'Online Only':
        return 'online_only';
      case 'Online + Walk-in':
        return 'online_walkin';
    }
    return null;
  }

  Future<String?> _uploadLogoIfNeeded() async {
    final file = _logoFile;
    if (file == null) return null;

    final storeId =
        _storeId ??
        _client.auth.currentUser?.userMetadata?['store_id']?.toString();
    if (storeId == null || storeId.trim().isEmpty) return null;

    final path = file.path;
    final extIndex = path.lastIndexOf('.');
    final ext = extIndex == -1 ? 'jpg' : path.substring(extIndex + 1);
    final storagePath = 'store-logos/$storeId/logo.$ext';

    await _client.storage
        .from('store-assets')
        .upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return 'store-assets/$storagePath';
  }

  Future<void> _saveLogoUrl(String logoPath) async {
    final storeId =
        _storeId ??
        _client.auth.currentUser?.userMetadata?['store_id']?.toString();
    if (storeId == null || storeId.trim().isEmpty) return;

    const tables = [
      'store_customization',
      'store_customizations',
      'stores',
      'Store',
    ];
    const storeIdColumns = [
      'store_id',
      'storeId',
      'storeid',
      'store_uuid',
      'shop_id',
      'shopId',
      'store_uuid_fk',
      'store',
      'id',
    ];

    for (final table in tables) {
      for (final column in storeIdColumns) {
        try {
          final result = await _client
              .from(table)
              .update({'logo_url': logoPath})
              .eq(column, storeId)
              .select();
          if (result is List && result.isNotEmpty) {
            return;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    final storeId =
        _storeId ??
        _client.auth.currentUser?.userMetadata?['store_id']?.toString();
    final idColumn = _storeIdColumn ?? 'id';
    final table = _storeTable ?? 'stores';
    if (storeId == null || storeId.trim().isEmpty) {
      if (!mounted) return;
      _showToast('Store not found.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      _putIfPresent(payload, const [
        'name',
        'store_name',
      ], _storeNameController.text.trim());
      _putIfPresent(payload, const ['category'], _selectedCategory);
      if (_businessModeDirty || _businessModeValue != null) {
        final modeValue =
            _businessModeValue ?? _businessModeToDb(_selectedBusinessMode);
        if (modeValue != null) {
          _putIfPresent(payload, const ['mode', 'business_mode'], modeValue);
        }
      }
      _putIfPresent(payload, const ['city'], _cityController.text.trim());
      _putIfPresent(payload, const ['state'], _stateController.text.trim());
      _putIfPresent(payload, const [
        'address',
        'full_address',
      ], _addressController.text.trim());
      _putIfPresent(payload, const ['is_active'], _isActive);

      final logoPath = await _uploadLogoIfNeeded();
      if (logoPath != null) {
        await _saveLogoUrl(logoPath);
        _logoUrl = _resolveLogoUrl(logoPath);
        _logoFile = null;
      }

      if (payload.isEmpty) {
        _showToast('No writable fields found.', isError: true);
        return;
      }

      await _client.from(table).update(payload).eq(idColumn, storeId);
      if (!mounted) return;
      if (logoPath != null && mounted) {
        setState(() {});
      }
      _showToast('Store settings saved successfully!');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showToast('Update failed: ${e.message}', isError: true);
    } catch (e) {
      if (!mounted) return;
      _showToast('Update failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String? _resolveLogoUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http')) return trimmed;
    var path = trimmed;
    const prefix = 'store-assets/';
    if (path.startsWith(prefix)) path = path.substring(prefix.length);
    return Supabase.instance.client.storage
        .from('store-assets')
        .getPublicUrl(path);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;
    setState(() => _logoFile = File(image.path));
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  // ── Input Decoration ──────────────────────────────────────────────────────
  InputDecoration _inputDec({String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _textSecondary.withOpacity(0.5),
        fontSize: 14,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: _textSecondary, size: 18)
          : null,
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  InputDecoration _dropDec({IconData? icon}) {
    return InputDecoration(
      prefixIcon: icon != null
          ? Icon(icon, color: _textSecondary, size: 18)
          : null,
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _storeInfo?.name ?? _storeNameController.text;
    final ImageProvider? logoProvider = _logoFile != null
        ? FileImage(_logoFile!)
        : (_logoUrl != null ? NetworkImage(_logoUrl!) as ImageProvider : null);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: DashboardDrawer(
        onClose: () => Navigator.of(context).pop(),
        store: _storeInfo,
        onOpenDashboard: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.dashboard,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenPosBilling: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.posBilling,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenOrders: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.orders,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenProducts: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.products,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenCustomers: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.customers,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenAnalytics: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.analytics,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenVendors: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.vendors,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenDelivery: () {
          ShellNav.switchAfterDrawerClose(
            context,
            ShellTab.delivery,
            closeDrawer: () => Navigator.of(context).pop(),
          );
        },
        onOpenStoreSettings: () => Navigator.of(context).pop(),
        activeStoreSettings: true,
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  slivers: [
                    TopHeaderSliver(
                      backgroundColor: _surface,
                      accent: _accent,
                      unreadNotifications: _unreadNotifications,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            )
                            .then((_) => _loadUnreadNotifications());
                      },
                      logoUrl: _logoUrl ?? _storeInfo?.logoUrl,
                      initials: _initials(storeName),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 20),
                          _settingsTitleBlock(),
                          const SizedBox(height: 20),
                          _buildLogoSection(logoProvider, storeName),
                          const SizedBox(height: 24),
                          _buildSectionLabel(
                            'Basic Information',
                            Icons.storefront_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildBasicInfoCard(),
                          const SizedBox(height: 24),
                          _buildSectionLabel(
                            'Location Details',
                            Icons.location_on_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildLocationCard(),
                          const SizedBox(height: 24),
                          _buildSectionLabel(
                            'Store Status',
                            Icons.toggle_on_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildStatusCard(),
                          const SizedBox(height: 32),
                          _buildSaveButton(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _settingsTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Store Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage your store profile',
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Logo Section ──────────────────────────────────────────────────────────
  Widget _buildLogoSection(ImageProvider? logoProvider, String storeName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accentLight.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: logoProvider != null
                      ? DecorationImage(image: logoProvider, fit: BoxFit.cover)
                      : null,
                  gradient: logoProvider == null
                      ? const LinearGradient(
                          colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: logoProvider == null
                    ? const Icon(
                        Icons.storefront_rounded,
                        color: _accent,
                        size: 32,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withOpacity(0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Store Logo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PNG or JPG · 200×200 px · max 2 MB',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accent.withOpacity(0.35)),
                      color: _accentSoft,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_rounded, size: 15, color: _accent),
                        SizedBox(width: 6),
                        Text(
                          'Upload New',
                          style: TextStyle(
                            fontSize: 13,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: _accent),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_divider, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Basic Info Card ───────────────────────────────────────────────────────
  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Store Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _storeNameController,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: _inputDec(
              hint: 'e.g. Lakshay Electronics',
              icon: Icons.storefront_outlined,
            ),
          ),
          const SizedBox(height: 18),
          _fieldLabel('Category'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: _surface,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSecondary,
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
            },
            decoration: _dropDec(icon: Icons.category_outlined),
          ),
          const SizedBox(height: 18),
          _fieldLabel('Business Mode'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBusinessMode,
            dropdownColor: _surface,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSecondary,
            ),
            items: _businessModes
                .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedBusinessMode = value;
                _businessModeValue = _businessModeToDb(value);
                _businessModeDirty = true;
              });
            },
            decoration: _dropDec(icon: Icons.business_center_outlined),
          ),
        ],
      ),
    );
  }

  // ── Location Card ─────────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('City'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cityController,
                      style: const TextStyle(color: _textPrimary, fontSize: 14),
                      decoration: _inputDec(
                        hint: 'e.g. Mumbai',
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('State'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stateController,
                      style: const TextStyle(color: _textPrimary, fontSize: 14),
                      decoration: _inputDec(
                        hint: 'e.g. Maharashtra',
                        icon: Icons.map_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _fieldLabel('Full Address'),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            maxLines: 3,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: _inputDec(
              hint: 'Shop no., street, area, pincode…',
              icon: Icons.pin_drop_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Card ───────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isActive ? _green.withOpacity(0.35) : _divider,
        ),
        boxShadow: [
          BoxShadow(
            color: _isActive
                ? _green.withOpacity(0.07)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isActive ? _greenSoft : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isActive
                  ? Icons.storefront_rounded
                  : Icons.store_mall_directory_outlined,
              color: _isActive ? _green : _textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _isActive ? _green : _textSecondary,
                  ),
                  child: Text(_isActive ? 'Store is Live' : 'Store is Offline'),
                ),
                const SizedBox(height: 3),
                Text(
                  _isActive
                      ? 'Customers can find and visit your store'
                      : 'Your store is hidden from customers',
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isActive,
            activeColor: _green,
            activeTrackColor: _greenSoft,
            inactiveThumbColor: const Color(0xFFD1D5DB),
            inactiveTrackColor: const Color(0xFFF3F4F6),
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }

  // ── Save Button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveChanges,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: _saving
                ? [_accentLight.withOpacity(0.5), _accent.withOpacity(0.4)]
                : [_accentLight, _accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: _saving
              ? []
              : [
                  BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Field Label ───────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _accent,
        unselectedItemColor: _textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 0) {
            ShellNav.switchTo(context, ShellTab.dashboard);
          } else if (index == 1) {
            ShellNav.switchTo(context, ShellTab.orders);
          } else if (index == 2) {
            ShellNav.switchTo(context, ShellTab.products);
          } else if (index == 4) {
            showMoreActionsSheet(
              context: context,
              onOpenDashboard: () =>
                  ShellNav.switchTo(context, ShellTab.dashboard),
              onOpenOrders: () => ShellNav.switchTo(context, ShellTab.orders),
              onOpenProducts: () =>
                  ShellNav.switchTo(context, ShellTab.products),
              onOpenPosBilling: () =>
                  ShellNav.switchTo(context, ShellTab.posBilling),
              onOpenAnalytics: () =>
                  ShellNav.switchTo(context, ShellTab.analytics),
              onOpenVendors: () => ShellNav.switchTo(context, ShellTab.vendors),
              onOpenAiUpload: () =>
                  ShellNav.switchTo(context, ShellTab.products),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_outlined),
            label: 'Share',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
