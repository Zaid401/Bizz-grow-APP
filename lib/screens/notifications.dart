import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Light Theme Colours ───────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF4F0FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFF6D28D9);
  static const Color _accentLight = Color(0xFF8B5CF6);
  static const Color _accentSoft = Color(0xFFEDE9FE);
  static const Color _textPrimary = Color(0xFF1E1340);
  static const Color _textSecondary = Color(0xFF7C6F99);
  static const Color _divider = Color(0xFFE8E0F5);
  static const Color _unreadDot = Color(0xFF7C3AED);
  static const Color _unreadBorder = Color(0xFFB39DDB);
  static const Color _readBg = Color(0xFFFAF8FE);

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
        dynamic query = _client.from('notifications').select('*');
        query = query.or('store_id.eq.$storeId,user_id.eq.$userId');
        query = query.order('created_at', ascending: false);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && storeId != null && storeId.trim().isNotEmpty) {
        dynamic query = _client.from('notifications').select('*');
        query = query.eq('store_id', storeId);
        query = query.order('created_at', ascending: false);
        final result = await query;
        rows = (result as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (rows.isEmpty && userId != null) {
        dynamic query = _client.from('notifications').select('*');
        query = query.eq('user_id', userId);
        query = query.order('created_at', ascending: false);
        final result = await query;
        rows = (result as List)
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
        final index = _items.indexWhere((row) => row['id'] == id);
        if (index >= 0) {
          final updated = Map<String, dynamic>.from(_items[index]);
          updated['is_read'] = true;
          final next = [..._items];
          next[index] = updated;
          _items = next;
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _items.where((e) => e['is_read'] != true).toList();
    if (unread.isEmpty) return;
    for (final item in unread) {
      await _markRead(item);
    }
  }

  String _safeText(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String _formatDate(Object? value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  int get _unreadCount => _items.where((e) => e['is_read'] != true).length;

  // ── Notification type icon & color ────────────────────────────────────────
  ({IconData icon, Color color, Color bg}) _typeStyle(
    Map<String, dynamic> item,
    bool isRead,
  ) {
    final type = _safeText(item['type']).toLowerCase();
    if (type.contains('order')) {
      return (
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF0369A1),
        bg: const Color(0xFFE0F2FE),
      );
    }
    if (type.contains('payment') || type.contains('money')) {
      return (
        icon: Icons.payments_outlined,
        color: const Color(0xFF059669),
        bg: const Color(0xFFD1FAE5),
      );
    }
    if (type.contains('alert') || type.contains('warn')) {
      return (
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFEF3C7),
      );
    }
    if (type.contains('product')) {
      return (
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFEDE9FE),
      );
    }
    // default
    return isRead
        ? (
            icon: Icons.notifications_none_rounded,
            color: _textSecondary,
            bg: const Color(0xFFF3F0F8),
          )
        : (
            icon: Icons.notifications_active_rounded,
            color: _accent,
            bg: _accentSoft,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                backgroundColor: _surface,
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _accent),
                      )
                    : _error != null
                    ? _buildError()
                    : _items.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
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
                    if (_unreadCount > 0)
                      Text(
                        '$_unreadCount unread',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _accent,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
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
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accent.withOpacity(0.25)),
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Unread count pill bar
          if (_items.isNotEmpty)
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: _divider,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                widthFactor: _items.isEmpty
                    ? 0
                    : 1 - (_unreadCount / _items.length),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accentLight, _accent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Container(height: 1, color: _divider),
        ],
      ),
    );
  }

  // ── Notification List ─────────────────────────────────────────────────────
  Widget _buildList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isRead = item['is_read'] == true;

          // Group label: Today / Yesterday / Earlier
          String? groupLabel;
          if (index == 0) {
            groupLabel = _groupLabel(item['created_at']);
          } else {
            final prev = _groupLabel(_items[index - 1]['created_at']);
            final curr = _groupLabel(item['created_at']);
            if (prev != curr) groupLabel = curr;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groupLabel != null) _buildGroupLabel(groupLabel),
              _buildNotificationCard(item, isRead),
            ],
          );
        },
      ),
    );
  }

  String _groupLabel(Object? value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Earlier';
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day));
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return 'Earlier';
  }

  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
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
                color: _accent,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: _divider)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item, bool isRead) {
    final title = _safeText(item['title'], fallback: 'Update');
    final message = _safeText(item['message']);
    final createdAt = _formatDate(item['created_at']);
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
                  : _accent.withOpacity(0.07),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
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
                        // Unread dot
                        if (!isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _unreadDot,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _unreadDot.withOpacity(0.4),
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
                          color: isRead
                              ? _textSecondary
                              : _textSecondary.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: _textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isRead) ...[
                          const Spacer(),
                          Text(
                            'Tap to mark read',
                            style: TextStyle(
                              fontSize: 10,
                              color: _accent.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
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

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
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
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
                ),
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
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
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
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 40,
                  color: Color(0xFFDC2626),
                ),
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
                style: TextStyle(fontSize: 13, color: _textSecondary),
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
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
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
}
