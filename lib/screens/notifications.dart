import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bizz_grow/loading/skeleton_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationsTab { all, settings }

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  _NotificationsTab _tab = _NotificationsTab.all;

  bool _orderNotifications = true;
  bool _stockAlerts = true;
  bool _customerUpdates = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _whatsAppUpdates = false;
  bool _smsUpdates = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF2EEF9);
  static const _surface = Color(0xFFFFFFFF);
  static const _accent = Color(0xFF5B21B6);
  static const _accentLight = Color(0xFF7C3AED);
  static const _accentSoft = Color(0xFFEDE9FE);
  static const _accentMid = Color(0xFFDDD6FE);
  static const _textPrimary = Color(0xFF1A0F2E);
  static const _textSec = Color(0xFF6B5E85);
  static const _divider = Color(0xFFE9E2F6);
  static const _unreadDot = Color(0xFF7C3AED);
  static const _unreadBorder = Color(0xFFB39DDB);
  static const _orderBlue = Color(0xFF1D4ED8);
  static const _orderBlueSoft = Color(0xFFDBEAFE);
  static const _payGreen = Color(0xFF047857);
  static const _payGreenSoft = Color(0xFFD1FAE5);
  static const _warnAmber = Color(0xFFB45309);
  static const _warnAmberSoft = Color(0xFFFEF3C7);
  static const _purple = Color(0xFF6D28D9);
  static const _purpleSoft = Color(0xFFEDE9FE);
  static const _red = Color(0xFFB91C1C);
  static const _redSoft = Color(0xFFFEE2E2);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _client.auth.currentUser;
      final userId = user?.id;
      final storeId = user?.userMetadata?['store_id']?.toString();
      List<Map<String, dynamic>> rows = const [];

      if (storeId != null && storeId.trim().isNotEmpty && userId != null) {
        dynamic q = _client.from('notifications').select('*');
        q = q
            .or('store_id.eq.$storeId,user_id.eq.$userId')
            .order('created_at', ascending: false);
        rows = ((await q) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic q = _client.from('notifications').select('*');
        q = q.eq('store_id', storeId).order('created_at', ascending: false);
        rows = ((await q) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && userId != null) {
        dynamic q = _client.from('notifications').select('*');
        q = q.eq('user_id', userId).order('created_at', ascending: false);
        rows = ((await q) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (!mounted) return;
      setState(() => _items = rows);
      _fadeController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null || item['is_read'] == true) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((r) => r['id'] == id);
        if (i >= 0) {
          final upd = Map<String, dynamic>.from(_items[i]);
          upd['is_read'] = true;
          final next = [..._items];
          next[i] = upd;
          _items = next;
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _visibleItems.where((e) => e['is_read'] != true).toList();
    for (final item in unread) await _markRead(item);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _safe(Object? v, {String fb = ''}) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return fb;
  }

  String _fmtDate(Object? value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    final l = date.toLocal();
    final diff = DateTime.now().difference(l);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  List<Map<String, dynamic>> get _visibleItems =>
      _items.where(_typeEnabled).toList();
  int get _unreadCount =>
      _visibleItems.where((e) => e['is_read'] != true).length;

  bool _typeEnabled(Map<String, dynamic> item) {
    final t = _safe(item['type']).toLowerCase();
    if (t.contains('order')) return _orderNotifications;
    if (t.contains('stock') || t.contains('inventory')) return _stockAlerts;
    if (t.contains('customer') || t.contains('review')) return _customerUpdates;
    return true;
  }

  ({IconData icon, Color color, Color bg}) _typeStyle(
    Map<String, dynamic> item,
    bool isRead,
  ) {
    final t = _safe(item['type']).toLowerCase();
    if (t.contains('order'))
      return (
        icon: Icons.shopping_bag_rounded,
        color: _orderBlue,
        bg: _orderBlueSoft,
      );
    if (t.contains('payment') || t.contains('money'))
      return (
        icon: Icons.payments_rounded,
        color: _payGreen,
        bg: _payGreenSoft,
      );
    if (t.contains('alert') || t.contains('warn'))
      return (
        icon: Icons.warning_amber_rounded,
        color: _warnAmber,
        bg: _warnAmberSoft,
      );
    if (t.contains('product'))
      return (icon: Icons.inventory_2_rounded, color: _purple, bg: _purpleSoft);
    return isRead
        ? (icon: Icons.notifications_rounded, color: _textSec, bg: _bg)
        : (
            icon: Icons.notifications_active_rounded,
            color: _accentLight,
            bg: _accentSoft,
          );
  }

  String _groupLabel(Object? value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Earlier';
    final l = date.toLocal();
    final now = DateTime.now();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(l.year, l.month, l.day));
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return 'Earlier';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final vis = _visibleItems;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(vis),
            _buildTabBar(),
            Expanded(
              child: RefreshIndicator(
                color: _accentLight,
                backgroundColor: _surface,
                onRefresh: _load,
                child: _tab == _NotificationsTab.settings
                    ? _buildSettings()
                    : _loading
                    ? NotificationSkeletonList()
                    : _error != null
                    ? _buildError()
                    : vis.isEmpty
                    ? _buildEmpty()
                    : _buildList(vis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(List<Map<String, dynamic>> vis) {
    final readCount = vis.where((e) => e['is_read'] == true).length;
    final totalCount = vis.length;
    final readFraction = totalCount == 0 ? 1.0 : readCount / totalCount;

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.only(left: 8, right: 8),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _divider),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _textPrimary,
                    size: 18,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _unreadCount > 0
                        ? RichText(
                            text: const TextSpan(
                              children: [
                                // dart const workaround — use Builder below
                              ],
                            ),
                          )
                        : const Text(
                            'All caught up \u2713',
                            style: TextStyle(
                              fontSize: 12,
                              color: _payGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ],
                ),
              ),
              if (_unreadCount > 0)
                GestureDetector(
                  onTap: _markAllRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentMid),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          color: _accentLight,
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 11,
                            color: _accentLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Subtitle row (build outside const to use _unreadCount)
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 54, top: 0, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_unreadCount unread',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _accentLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' \u00b7 ${vis.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSec,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Progress bar
          if (vis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: readFraction),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: _divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _accentLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$readCount of $totalCount read',
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSec.withOpacity(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Container(height: 1, color: _divider),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          _tabChip(
            Icons.notifications_rounded,
            'Notifications',
            _NotificationsTab.all,
          ),
          _tabChip(Icons.tune_rounded, 'Settings', _NotificationsTab.settings),
        ],
      ),
    ),
  );

  Widget _tabChip(IconData icon, String label, _NotificationsTab tab) {
    final active = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : _textSec),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _textSec,
                ),
              ),
              if (tab == _NotificationsTab.all &&
                  _unreadCount > 0 &&
                  !active) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_unreadCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _accentLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> items) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isRead = item['is_read'] == true;
          String? groupLabel;
          if (index == 0) {
            groupLabel = _groupLabel(item['created_at']);
          } else {
            final prev = _groupLabel(items[index - 1]['created_at']);
            final curr = _groupLabel(item['created_at']);
            if (prev != curr) groupLabel = curr;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groupLabel != null) _buildGroupLabel(groupLabel),
              _buildCard(item, isRead),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _accentLight,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_divider, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, bool isRead) {
    final title = _safe(item['title'], fb: 'Update');
    final message = _safe(item['message']);
    final timeText = _fmtDate(item['created_at']);
    final style = _typeStyle(item, isRead);

    return GestureDetector(
      onTap: () => _markRead(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? _surface : const Color(0xFFFBF9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? _divider : _unreadBorder,
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isRead
                  ? Colors.black.withOpacity(0.03)
                  : _accent.withOpacity(0.08),
              blurRadius: isRead ? 8 : 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: style.color.withOpacity(0.15)),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _unreadDot,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _unreadDot.withOpacity(0.45),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isRead ? _textSec : _textSec.withOpacity(0.9),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: _textSec.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSec.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isRead) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _accentSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Tap to mark read',
                              style: TextStyle(
                                fontSize: 10,
                                color: _accentLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  // ── Settings ───────────────────────────────────────────────────────────────
  Widget _buildSettings() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const Text(
          'Manage your notification preferences',
          style: TextStyle(fontSize: 12, color: _textSec),
        ),
        const SizedBox(height: 16),
        _section(Icons.tune_rounded, 'Notification Types', [
          _tile(
            Icons.shopping_bag_rounded,
            _orderBlue,
            _orderBlueSoft,
            'Order Notifications',
            'New orders, status updates',
            _orderNotifications,
            (v) => setState(() => _orderNotifications = v),
          ),
          _tile(
            Icons.warning_amber_rounded,
            _warnAmber,
            _warnAmberSoft,
            'Stock Alerts',
            'Low stock and out of stock warnings',
            _stockAlerts,
            (v) => setState(() => _stockAlerts = v),
          ),
          _tile(
            Icons.people_alt_rounded,
            _purple,
            _purpleSoft,
            'Customer Updates',
            'New customers, reviews',
            _customerUpdates,
            (v) => setState(() => _customerUpdates = v),
            last: true,
          ),
        ]),
        const SizedBox(height: 16),
        _section(Icons.send_rounded, 'Delivery Channels', [
          _tile(
            Icons.mail_rounded,
            _orderBlue,
            _orderBlueSoft,
            'Email',
            'Receive notifications via email',
            _emailNotifications,
            (v) => setState(() => _emailNotifications = v),
          ),
          _tile(
            Icons.notifications_active_rounded,
            _accentLight,
            _accentSoft,
            'Push Notifications',
            'Browser and mobile push',
            _pushNotifications,
            (v) => setState(() => _pushNotifications = v),
          ),
          _tile(
            Icons.chat_rounded,
            _payGreen,
            _payGreenSoft,
            'WhatsApp',
            'Get updates on WhatsApp',
            _whatsAppUpdates,
            (v) => setState(() => _whatsAppUpdates = v),
          ),
          _tile(
            Icons.sms_rounded,
            _warnAmber,
            _warnAmberSoft,
            'SMS',
            'Text message notifications',
            _smsUpdates,
            (v) => setState(() => _smsUpdates = v),
            last: true,
          ),
        ]),
      ],
    );
  }

  Widget _section(IconData icon, String title, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _accentLight, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_divider, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _tile(
    IconData icon,
    Color iconColor,
    Color iconBg,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool last = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor.withOpacity(0.15)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _textSec),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: _accentLight,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!last) Container(height: 1, color: _divider.withOpacity(0.7)),
      ],
    );
  }

  // ── Empty / Error ──────────────────────────────────────────────────────────
  Widget _buildEmpty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 80),
      Center(
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 40,
                color: _accentLight,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're all caught up!\nNew updates will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSec, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentLight, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
  );

  Widget _buildError() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 80),
      Center(
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: _redSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: _red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pull down to try again.',
              style: TextStyle(fontSize: 13, color: _textSec),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _redSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
  );
}
