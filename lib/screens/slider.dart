import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({
    super.key,
    required this.onClose,
    this.store,
    this.onOpenPosBilling,
    this.onOpenDashboard,
    this.onOpenOrders,
    this.onOpenProducts,
    this.onOpenCustomers,
    this.onOpenAnalytics,
    this.onOpenVendors,
    this.onOpenDelivery,
    this.onOpenStoreSettings,
    this.onOpenAiUpload,
    this.activeDashboard = false,
    this.activePosBilling = false,
    this.activeOrders = false,
    this.activeProducts = false,
    this.activeCustomers = false,
    this.activeAnalytics = false,
    this.activeVendors = false,
    this.activeDelivery = false,
    this.activeStoreSettings = false,
    this.activeAiUpload = false,
  });

  final VoidCallback onClose;
  final StoreInfo? store;
  final VoidCallback? onOpenPosBilling;
  final VoidCallback? onOpenDashboard;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenCustomers;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenVendors;
  final VoidCallback? onOpenDelivery;
  final VoidCallback? onOpenStoreSettings;
  final VoidCallback? onOpenAiUpload;
  final bool activeDashboard;
  final bool activePosBilling;
  final bool activeOrders;
  final bool activeProducts;
  final bool activeCustomers;
  final bool activeAnalytics;
  final bool activeVendors;
  final bool activeDelivery;
  final bool activeStoreSettings;
  final bool activeAiUpload;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF2EEF9);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFF5B21B6);
  static const Color _accentLight = Color(0xFF7C3AED);
  static const Color _accentSoft = Color(0xFFEDE9FE);
  static const Color _accentMid = Color(0xFFDDD6FE);
  static const Color _gold = Color(0xFFD97706);
  static const Color _goldSoft = Color(0xFFFEF3C7);
  static const Color _textPrimary = Color(0xFF1A0F2E);
  static const Color _textSecondary = Color(0xFF6B5E85);
  static const Color _divider = Color(0xFFE9E2F6);
  static const Color _green = Color(0xFF047857);
  static const Color _greenSoft = Color(0xFFD1FAE5);
  static const Color _red = Color(0xFFB91C1C);
  static const Color _redSoft = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final storeName = store?.name ?? 'Biz Grow';
    final storeCategory = store?.category ?? 'Retail';
    final storeStatus = store?.status ?? 'Active';
    final isActive = storeStatus.toLowerCase() == 'active';

    return Drawer(
      width: 300,
      backgroundColor: _bg,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── App brand header ───────────────────────────────────
                    _buildBrandHeader(),
                    const SizedBox(height: 14),

                    // ── Store info card ────────────────────────────────────
                    _buildStoreCard(
                      storeName,
                      storeCategory,
                      storeStatus,
                      isActive,
                    ),
                    const SizedBox(height: 8),

                    // ── Main Menu ──────────────────────────────────────────
                    _sectionLabel('Main Menu'),
                    _menuItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                      active: activeDashboard,
                      onTap: onOpenDashboard,
                    ),
                    _menuItem(
                      icon: Icons.point_of_sale_rounded,
                      label: 'POS Billing',
                      active: activePosBilling,
                      onTap: onOpenPosBilling,
                    ),
                    _menuItem(
                      icon: Icons.shopping_bag_rounded,
                      label: 'Orders',
                      active: activeOrders,
                      onTap: onOpenOrders,
                    ),
                    _menuItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Products',
                      active: activeProducts,
                      onTap: onOpenProducts,
                    ),
                    _menuItem(
                      icon: Icons.people_alt_rounded,
                      label: 'Customers',
                      active: activeCustomers,
                      onTap: onOpenCustomers,
                    ),
                    _menuItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      active: activeAnalytics,
                      onTap: onOpenAnalytics,
                    ),
                    _menuItem(
                      icon: Icons.storefront_rounded,
                      label: 'Vendors',
                      active: activeVendors,
                      onTap: onOpenVendors,
                    ),

                    // ── Tools ──────────────────────────────────────────────
                    _sectionLabel('Tools'),
                    _menuItem(
                      icon: Icons.link_rounded,
                      label: 'Catalogue Link',
                      onTap: onClose,
                    ),
                    _menuItem(
                      icon: Icons.tune_rounded,
                      label: 'Customize Store',
                      onTap: onClose,
                    ),
                    _menuItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Upload',
                      badge: 'NEW',
                      active: activeAiUpload,
                      onTap: onOpenAiUpload ?? onClose,
                    ),
                    _menuItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      onTap: onClose,
                    ),
                    _menuItem(
                      icon: Icons.local_shipping_rounded,
                      label: 'Delivery',
                      active: activeDelivery,
                      onTap: onOpenDelivery,
                    ),

                    // ── Settings ───────────────────────────────────────────
                    _sectionLabel('Settings'),
                    _menuItem(
                      icon: Icons.storefront_rounded,
                      label: 'Store Settings',
                      active: activeStoreSettings,
                      onTap: onOpenStoreSettings ?? onClose,
                    ),
                    _menuItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Billing',
                      onTap: onClose,
                    ),
                    _menuItem(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      onTap: onClose,
                    ),
                    _menuItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: onClose,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Divider + Logout ───────────────────────────────────────────
            Container(height: 1, color: _divider),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  // ── Brand Header ───────────────────────────────────────────────────────────
  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentLight, _accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Biz Grow ',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: '360°',
                  style: TextStyle(
                    color: _accentLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'v1.0',
              style: TextStyle(
                fontSize: 10,
                color: _accentLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Store Card ─────────────────────────────────────────────────────────────
  Widget _buildStoreCard(
    String name,
    String category,
    String status,
    bool isActive,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentSoft, _accentMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _accentMid),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: _accentLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? _greenSoft : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? _green.withOpacity(0.3) : _divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? _green : _textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: isActive ? _green : _textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
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

  // ── Menu Item ──────────────────────────────────────────────────────────────
  Widget _menuItem({
    required IconData icon,
    required String label,
    bool active = false,
    bool disabled = false,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active ? _accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active ? _accentMid : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? _accent.withOpacity(0.12)
                        : disabled
                        ? const Color(0xFFF3F0F8)
                        : const Color(0xFFF5F2FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: disabled
                        ? _textSecondary.withOpacity(0.4)
                        : active
                        ? _accent
                        : _textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: disabled
                          ? _textSecondary.withOpacity(0.4)
                          : active
                          ? _accent
                          : _textPrimary,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Active indicator bar
                if (active)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                // Badge
                if (badge != null && !active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _goldSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withOpacity(0.3)),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                // Coming soon for disabled
                if (disabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logout Button ──────────────────────────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: GestureDetector(
        onTap: () => _confirmLogout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _redSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: _red, size: 20),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: _red, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout Confirmation Dialog ─────────────────────────────────────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _redSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: _red, size: 26),
              ),
              const SizedBox(height: 18),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to\nlogout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Confirm button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Yes, Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Cancel
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F2FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Logout failed. Please try again.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
  }
}
