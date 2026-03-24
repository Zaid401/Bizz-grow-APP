import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_upload_service.dart';
import '../services/dashboard_repository.dart';
import '../widgets/more_actions_sheet.dart';
import '../widgets/shell_nav.dart';
import 'notifications.dart';
import 'slider.dart';

final String _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

class _C {
  static const bg = Color(0xFFF2EEF9);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF5B21B6);
  static const accentLight = Color(0xFF7C3AED);
  static const accentSoft = Color(0xFFEDE9FE);
  static const accentMid = Color(0xFFDDD6FE);
  static const textPrimary = Color(0xFF1A0F2E);
  static const textSecondary = Color(0xFF6B5E85);
  static const divider = Color(0xFFE9E2F6);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);
  static const purple = Color(0xFF6D28D9);
  static const purpleSoft = Color(0xFFEDE9FE);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFD1FAE5);
  static const red = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
}

class _AnalysisStep {
  const _AnalysisStep(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

const _analysisSteps = [
  _AnalysisStep('Uploading image...', Icons.cloud_upload_rounded, _C.blue),
  _AnalysisStep(
    'Scanning product...',
    Icons.document_scanner_rounded,
    _C.purple,
  ),
  _AnalysisStep('Extracting details...', Icons.auto_awesome_rounded, _C.amber),
  _AnalysisStep(
    'Enhancing image...',
    Icons.auto_fix_high_rounded,
    _C.accentLight,
  ),
  _AnalysisStep(
    'Filling in product info...',
    Icons.edit_note_rounded,
    _C.green,
  ),
];

class AiUploadScreen extends StatefulWidget {
  const AiUploadScreen({super.key});
  @override
  State<AiUploadScreen> createState() => _AiUploadScreenState();
}

class _AiUploadScreenState extends State<AiUploadScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final AiUploadService _aiUploadService = AiUploadService();
  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _catCtrl = TextEditingController();

  StoreInfo? _storeInfo;
  bool _loading = true;
  bool _analyzing = false;
  bool _saving = false;
  File? _selectedImage;
  int _unreadNotifications = 0;

  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _stepController;
  late AnimationController _shimmerController;
  AnimationController? _pageController;

  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _stepAnim;
  late Animation<double> _shimmerAnim;
  Animation<double> _pageFadeAnim = const AlwaysStoppedAnimation(1);
  Animation<Offset> _pageSlideAnim = const AlwaysStoppedAnimation(Offset.zero);

  int _currentStep = 0;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stepAnim = CurvedAnimation(parent: _stepController, curve: Curves.easeOut);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pageFadeAnim = CurvedAnimation(
      parent: _pageController!,
      curve: Curves.easeOut,
    );
    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageController!, curve: Curves.easeOut));
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _stepController.dispose();
    _shimmerController.dispose();
    _pageController?.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _tickSteps() async {
    for (int i = 0; i < _analysisSteps.length; i++) {
      if (!mounted) return;
      setState(() => _currentStep = i);
      _stepController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dash = await _dashboardRepository.fetch();
      if (!mounted) return;
      setState(() => _storeInfo = dash.storeInfo);
      await _loadUnreadNotifications();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final storeId = user?.userMetadata?['store_id']?.toString();
      List<Map<String, dynamic>> rows = const [];

      if (storeId != null && storeId.trim().isNotEmpty && userId != null) {
        dynamic query = _supabase.from('notifications').select('id');
        query = query.eq('is_read', false);
        query = query.or('store_id.eq.$storeId,user_id.eq.$userId');
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic query = _supabase.from('notifications').select('id');
        query = query.eq('is_read', false).eq('store_id', storeId);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && userId != null) {
        dynamic query = _supabase.from('notifications').select('id');
        query = query.eq('is_read', false).eq('user_id', userId);
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

  Future<void> _pickImage(ImageSource source) async {
    if (_analyzing) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) {
        _showSnack('No image selected.');
        return;
      }
      setState(() {
        _selectedImage = File(picked.path);
        _showSuccess = false;
      });
      await _analyzeImage();
    } catch (_) {
      _showSnack('Unable to pick image. Please try again.');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _analyzing = true;
      _currentStep = 0;
    });
    final stepFuture = _tickSteps();
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _guessMimeType(_selectedImage!.path);
      final dataUrl = 'data:$mimeType;base64,$base64Image';
      final data = await _aiUploadService.analyzeProduct(dataUrl);
      _nameCtrl.text = _firstVal(data, [
        'name',
        'productName',
        'product_name',
        'title',
      ]);
      _priceCtrl.text = _firstVal(data, ['price', 'mrp', 'amount']);
      _descCtrl.text = _firstVal(data, ['description', 'desc', 'details']);
      _catCtrl.text = _firstVal(data, [
        'category',
        'categoryName',
        'category_name',
      ]);
      await stepFuture;
      final hasData = [
        _nameCtrl,
        _priceCtrl,
        _descCtrl,
        _catCtrl,
      ].any((c) => c.text.trim().isNotEmpty);
      _showSnack(
        hasData
            ? 'Product details extracted!'
            : 'AI responded but no fields found.',
      );
    } catch (e) {
      await stepFuture;
      _showSnack('AI analysis failed: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _addProductToStore() async {
    if (_saving || _analyzing) return;
    if (_selectedImage == null) {
      _showSnack('Please select an image first.');
      return;
    }
    final name = _nameCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    if (name.isEmpty || price.isEmpty) {
      _showSnack('Product name and price are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final storeId = await _resolveStoreId();
      final imageUrl = await _uploadImage(_selectedImage!);
      final response = await http.post(
        Uri.parse('https://zyaawadtgdvawkdmnkcz.supabase.co/rest/v1/products'),
        headers: _restHeaders,
        body: jsonEncode({
          if (storeId != null) 'store_id': storeId,
          'name': name,
          'description': _descCtrl.text.trim(),
          'price': double.tryParse(price) ?? 0,
          'compare_price': 0,
          'category': _catCtrl.text.trim(),
          'image_url': imageUrl,
          'is_available': true,
          'stock_quantity': 0,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showSnack('Upload failed: ${response.body}');
        return;
      }
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      _resetAfterAdd();
    } catch (e) {
      _showSnack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetAfterAdd() => setState(() {
    _selectedImage = null;
    _showSuccess = false;
    _nameCtrl.clear();
    _priceCtrl.clear();
    _descCtrl.clear();
    _catCtrl.clear();
  });

  Map<String, String> get _restHeaders => {
    'apikey': _supabaseAnonKey,
    'Authorization': 'Bearer $_supabaseAnonKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  Future<String?> _resolveStoreId() async {
    final user = _supabase.auth.currentUser;
    final meta = user?.userMetadata?['store_id']?.toString();
    if (meta != null && meta.isNotEmpty) return meta;
    if (user == null) return null;
    final stores = await _supabase
        .from('stores')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);
    if (stores is List && stores.isNotEmpty)
      return (stores.first as Map)['id']?.toString();
    return null;
  }

  Future<String> _uploadImage(File f) async {
    const bucket = 'product-images';
    final ext = f.path.split('.').last;
    final name = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final objPath = 'products/$name';
    final uri = Uri.parse(
      'https://zyaawadtgdvawkdmnkcz.supabase.co/storage/v1/object/$bucket/$objPath',
    );
    final res = await http.put(
      uri,
      headers: {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': _mime(ext),
        'x-upsert': 'true',
      },
      body: await f.readAsBytes(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300)
      throw Exception('Image upload failed: ${res.body}');
    return 'https://zyaawadtgdvawkdmnkcz.supabase.co/storage/v1/object/public/$bucket/$objPath';
  }

  String _mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _guessMimeType(String path) {
    final l = path.toLowerCase();
    if (l.endsWith('.png')) return 'image/png';
    if (l.endsWith('.heic')) return 'image/heic';
    if (l.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _firstVal(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bg,
      drawer: DashboardDrawer(
        store: _storeInfo,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
        onOpenDashboard: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.dashboard,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenPosBilling: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.posBilling,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenOrders: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.orders,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenProducts: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.products,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenCustomers: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.customers,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenAnalytics: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.analytics,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenVendors: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.vendors,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenDelivery: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.delivery,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenStoreSettings: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.storeSettings,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        onOpenAiUpload: () => ShellNav.switchAfterDrawerClose(
          context,
          ShellTab.aiUpload,
          closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        activeAiUpload: true,
      ),
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomNav(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F4FF), Color(0xFFEEE7FF), Color(0xFFE0D7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _C.accentLight),
                )
              : FadeTransition(
                  opacity: _pageFadeAnim,
                  child: SlideTransition(
                    position: _pageSlideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildHeroBadge(),
                          const SizedBox(height: 16),
                          _buildHeroText(),
                          const SizedBox(height: 22),
                          _buildUploadCard(),
                          const SizedBox(height: 18),
                          // ── DYNAMIC ANIMATION CARD appears here while analyzing ──
                          if (_analyzing) _buildAnalyzingCard(),
                          // ── Preview + form shown only after analysis finishes ──
                          if (!_analyzing && _selectedImage != null) ...[
                            _buildPreviewCard(),
                            const SizedBox(height: 18),
                            _buildDetailsForm(),
                            const SizedBox(height: 16),
                            _buildAddButton(),
                          ],
                          const SizedBox(height: 26),
                          _buildFeatureBadges(),
                          const SizedBox(height: 20),
                          _buildQuickStats(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasLogo =
        _storeInfo?.logoUrl != null && _storeInfo!.logoUrl!.trim().isNotEmpty;
    return AppBar(
      backgroundColor: _C.bg,
      elevation: 0,
      surfaceTintColor: _C.bg,
      centerTitle: true,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu_rounded, color: Color(0xFF4A3A59)),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: _C.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'AI Upload',
              style: TextStyle(
                color: _C.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                )
                .then((_) => _loadUnreadNotifications());
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF4A3A59),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      _unreadNotifications > 9
                          ? '9+'
                          : _unreadNotifications.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: hasLogo ? Colors.transparent : _C.accent,
            backgroundImage: hasLogo
                ? NetworkImage(_storeInfo!.logoUrl!)
                : null,
            child: hasLogo
                ? null
                : Text(
                    _initials(_storeInfo?.name ?? 'Store'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  Widget _buildHeroBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: _C.accentSoft,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _C.accentMid),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, color: _C.accent, size: 14),
        SizedBox(width: 6),
        Text(
          'AI-Powered Product Upload',
          style: TextStyle(
            color: _C.accent,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildHeroText() => const Column(
    children: [
      Text(
        'Add Products in Seconds',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: _C.textPrimary,
          letterSpacing: -0.4,
        ),
      ),
      SizedBox(height: 10),
      Text(
        'Snap a photo \u00b7 AI extracts details \u00b7 Done!',
        textAlign: TextAlign.center,
        style: TextStyle(color: _C.textSecondary, fontSize: 13.5, height: 1.5),
      ),
    ],
  );

  Widget _buildUploadCard() => _GlassCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      children: [
        ScaleTransition(
          scale: _analyzing ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Upload Product Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Snap or upload a product photo.\nOur AI will extract all the details automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: _C.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _PressableScale(
          onTap: _analyzing ? null : () => _pickImage(ImageSource.camera),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Take Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PressableScale(
          onTap: _analyzing ? null : () => _pickImage(ImageSource.gallery),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.divider),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_rounded, color: _C.textSecondary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Upload from Gallery',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: const [
            _FeatureChip(icon: Icons.image_rounded, text: 'JPG, PNG, HEIC'),
            _FeatureChip(icon: Icons.cloud_upload_rounded, text: 'Max 10MB'),
            _FeatureChip(icon: Icons.photo_library_rounded, text: 'Up to 20'),
          ],
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // DYNAMIC ANALYZING CARD — replaces plain "Analyzing product..." text
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyzingCard() {
    final step =
        _analysisSteps[_currentStep.clamp(0, _analysisSteps.length - 1)];
    final progress = (_currentStep + 1) / _analysisSteps.length;
    return _GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // 1) Rotating sweep-gradient ring with step icon inside
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, child) =>
                Transform.rotate(angle: _rotateAnim.value, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    _C.accentLight.withOpacity(0.0),
                    _C.accentLight.withOpacity(0.7),
                    _C.accent,
                    _C.accentLight.withOpacity(0.0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _C.accent.withOpacity(0.15),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  // 2) Step icon switches via AnimatedSwitcher
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Icon(
                      step.icon,
                      key: ValueKey(_currentStep),
                      color: step.color,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 3) Step label switches via AnimatedSwitcher with slide
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              step.label,
              key: ValueKey(_currentStep),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Step ${_currentStep + 1} of ${_analysisSteps.length}',
            style: const TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 20),
          // 4) Smooth TweenAnimationBuilder progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: _C.accentSoft,
                valueColor: AlwaysStoppedAnimation<Color>(_C.accentLight),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 5) Animated step dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_analysisSteps.length, (i) {
              final done = i < _currentStep;
              final active = i == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: done
                      ? _C.green
                      : active
                      ? _C.accentLight
                      : _C.divider,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // 6) Shimmer rows
          _buildShimmerRows(),
          const SizedBox(height: 14),
          Text(
            'This usually takes a few seconds...',
            style: TextStyle(
              fontSize: 11.5,
              color: _C.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerRows() {
    final widths = [0.85, 0.6, 0.72];
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        return Column(
          children: List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              height: 13,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment(_shimmerAnim.value - 1, 0),
                  end: Alignment(_shimmerAnim.value + 1, 0),
                  colors: [_C.divider, _C.accentSoft, _C.divider],
                ),
              ),
              child: FractionallySizedBox(
                widthFactor: widths[index],
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _selectedImage == null ? 0 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        scale: _selectedImage == null ? 0.98 : 1,
        child: _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    if (_analyzing)
                      Positioned.fill(
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                            child: Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _C.greenSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _C.green,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Image selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _PressableScale(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _C.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _C.accentMid),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 13,
                              color: _C.accentLight,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _C.accentLight,
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
        ),
      ),
    );
  }

  Widget _buildDetailsForm() => _GlassCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.edit_note_rounded, 'Product Details'),
        const SizedBox(height: 16),
        _formField('Product Name', _nameCtrl, icon: Icons.inventory_2_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _formField(
                'Price (\u20b9)',
                _priceCtrl,
                keyboard: TextInputType.number,
                icon: Icons.currency_rupee_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _formField(
                'Category',
                _catCtrl,
                icon: Icons.label_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _formField(
          'Description',
          _descCtrl,
          maxLines: 3,
          icon: Icons.notes_rounded,
        ),
      ],
    ),
  );

  Widget _formField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : null,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: _C.textSecondary, size: 17)
            : null,
        filled: true,
        fillColor: _C.bg,
        contentPadding: EdgeInsets.symmetric(
          horizontal: icon != null ? 6 : 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: _C.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: _C.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _C.accentLight, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAddButton() => _PressableScale(
    onTap: _analyzing || _saving ? null : _addProductToStore,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: _saving || _analyzing
            ? null
            : const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: _saving || _analyzing ? _C.divider : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _saving || _analyzing
            ? []
            : [
                BoxShadow(
                  color: _C.accent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
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
                  color: _C.accentLight,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_box_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Add Product to Store',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _sectionHeader(IconData icon, String title) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _C.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _C.accentLight, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _C.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_C.divider, Colors.transparent]),
          ),
        ),
      ),
    ],
  );

  Widget _buildFeatureBadges() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 10,
    runSpacing: 10,
    children: const [
      _FeatureBadge(label: 'Detects 1000+ products', icon: Icons.flash_on),
      _FeatureBadge(label: 'Auto-categorization', icon: Icons.auto_awesome),
      _FeatureBadge(label: 'Price extraction', icon: Icons.price_check),
      _FeatureBadge(label: 'Clean backgrounds', icon: Icons.auto_fix_high),
    ],
  );

  Widget _buildQuickStats() => LayoutBuilder(
    builder: (_, constraints) {
      final w = (constraints.maxWidth - 24) / 3;
      return Row(
        children: [
          SizedBox(
            width: w,
            child: const _StatTile(
              title: '<5 sec',
              subtitle: 'Instant\nDetection',
              icon: Icons.flash_on_rounded,
              tint: _C.amber,
              soft: _C.amberSoft,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: w,
            child: const _StatTile(
              title: 'Clean BG',
              subtitle: 'Auto\nEnhancement',
              icon: Icons.auto_fix_high_rounded,
              tint: _C.purple,
              soft: _C.purpleSoft,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: w,
            child: const _StatTile(
              title: '10x faster',
              subtitle: 'Time Saved',
              icon: Icons.timelapse_rounded,
              tint: _C.green,
              soft: _C.greenSoft,
            ),
          ),
        ],
      );
    },
  );

  Widget _buildBottomNav() => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      border: Border(top: BorderSide(color: _C.divider)),
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
      currentIndex: 4,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: _C.accent,
      unselectedItemColor: _C.textSecondary,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) {
        if (index == 0)
          ShellNav.switchTo(context, ShellTab.dashboard);
        else if (index == 1)
          ShellNav.switchTo(context, ShellTab.orders);
        else if (index == 2)
          ShellNav.switchTo(context, ShellTab.products);
        else if (index == 4)
          showMoreActionsSheet(
            context: context,
            onOpenDashboard: () =>
                ShellNav.switchTo(context, ShellTab.dashboard),
            onOpenOrders: () => ShellNav.switchTo(context, ShellTab.orders),
            onOpenProducts: () => ShellNav.switchTo(context, ShellTab.products),
            onOpenPosBilling: () =>
                ShellNav.switchTo(context, ShellTab.posBilling),
            onOpenAnalytics: () =>
                ShellNav.switchTo(context, ShellTab.analytics),
            onOpenVendors: () => ShellNav.switchTo(context, ShellTab.vendors),
            activeModule: MoreActionsModule.aiUpload,
            onOpenAiUpload: () => ShellNav.switchTo(context, ShellTab.aiUpload),
          );
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_rounded),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_rounded),
          label: 'Products',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.share_rounded),
          label: 'Share',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'More'),
      ],
    ),
  );

  Future<void> _showSuccessDialog() async {
    final name = _nameCtrl.text.trim();
    final category = _catCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    final parentCtx = context;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: _C.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Upload Successful!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1 product added to your catalogue',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRODUCT ADDED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _C.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.divider),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _selectedImage == null
                              ? Container(
                                  width: 52,
                                  height: 52,
                                  color: _C.accentSoft,
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    color: _C.accent,
                                    size: 22,
                                  ),
                                )
                              : Image.file(
                                  _selectedImage!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'New Product' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _C.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.label_rounded,
                                    size: 11,
                                    color: _C.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    category.isEmpty
                                        ? 'Uncategorized'
                                        : category,
                                    style: const TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          price.isEmpty ? '\u20b90' : '\u20b9$price',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _resetAfterAdd();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _C.divider),
                            ),
                            child: const Center(
                              child: Text(
                                'Add More',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _C.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            ShellNav.switchTo(parentCtx, ShellTab.products);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_C.accentLight, _C.accent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: _C.accent.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'View Products',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepInfo {
  const _StepInfo({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.soft,
  });
  final int step;
  final IconData icon;
  final String title, description;
  final Color color, soft;
}

const List<_StepInfo> _steps = [
  _StepInfo(
    step: 1,
    icon: Icons.photo_camera_rounded,
    title: 'Snap or Upload',
    description: 'Take a photo or upload from your gallery.',
    color: _C.blue,
    soft: _C.blueSoft,
  ),
  _StepInfo(
    step: 2,
    icon: Icons.psychology_rounded,
    title: 'AI Analyzes',
    description: 'Our AI detects product type and extracts all details.',
    color: _C.purple,
    soft: _C.purpleSoft,
  ),
  _StepInfo(
    step: 3,
    icon: Icons.auto_fix_high_rounded,
    title: 'Auto Enhance',
    description: 'Gets a clean white background automatically.',
    color: _C.amber,
    soft: _C.amberSoft,
  ),
  _StepInfo(
    step: 4,
    icon: Icons.inventory_2_rounded,
    title: 'Add to Catalogue',
    description: 'Review, edit if needed, and publish.',
    color: _C.green,
    soft: _C.greenSoft,
  ),
];

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});
  final _StepInfo step;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.divider),
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: step.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(step.icon, color: step.color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              step.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 12,
                color: _C.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      Positioned(
        right: 12,
        top: 12,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _C.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.accent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '${step.step}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    ],
  );
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEDE9FE), Color(0xFFDAD0FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _C.accentMid),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _C.accent, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _C.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.soft,
  });
  final String title, subtitle;
  final IconData icon;
  final Color tint, soft;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _C.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: soft,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tint.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: tint, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: _C.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEDE9FE), Color(0xFFE0D7FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.accentMid),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _C.accent),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.97 : 1,
      child: widget.child,
    ),
  );
}
