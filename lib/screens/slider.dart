import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

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
    this.onOpenDelivery,
    this.activeDashboard = false,
    this.activePosBilling = false,
    this.activeOrders = false,
    this.activeProducts = false,
    this.activeCustomers = false,
    this.activeAnalytics = false,
    this.activeDelivery = false,
  });

  final VoidCallback onClose;
  final StoreInfo? store;
  final VoidCallback? onOpenPosBilling;
  final VoidCallback? onOpenDashboard;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenCustomers;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenDelivery;
  final bool activeDashboard;
  final bool activePosBilling;
  final bool activeOrders;
  final bool activeProducts;
  final bool activeCustomers;
  final bool activeAnalytics;
  final bool activeDelivery;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF2B0B45);
    const card = Color(0xFF3B0F5C);
    const highlight = Color(0xFFFFD34D);

    final storeName = store?.name ?? 'Biz Grow';
    final storeCategory = store?.category ?? 'Retail';
    final storeStatus = store?.status ?? 'Active';

    Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC9B8E0),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget menuItem(
      IconData icon,
      String label, {
      bool active = false,
      bool pill = false,
      VoidCallback? onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: active ? highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(color: Colors.transparent)
                : Border.all(color: const Color(0xFF40245D)),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              icon,
              color: active ? Colors.black87 : Colors.white,
              size: 20,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: active ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: pill
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
            onTap: onTap ?? onClose,
          ),
        ),
      );
    }

    return Drawer(
      width: 300,
      backgroundColor: bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Text(
                      'Biz Grow ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '360°',
                      style: TextStyle(
                        color: highlight,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              storeCategory,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          storeStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Menu
              sectionTitle('Main Menu'),
              menuItem(
                Icons.grid_view_rounded,
                'Dashboard',
                active: activeDashboard,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenDashboard?.call();
                },
              ),
              menuItem(
                Icons.point_of_sale,
                'POS Billing',
                active: activePosBilling,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenPosBilling?.call();
                },
              ),
              menuItem(
                Icons.shopping_bag_outlined,
                'Orders',
                active: activeOrders,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenOrders?.call();
                },
              ),
              menuItem(
                Icons.inventory_2_outlined,
                'Products',
                active: activeProducts,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenProducts?.call();
                },
              ),
              menuItem(
                Icons.people_alt_outlined,
                'Customers',
                active: activeCustomers,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenCustomers?.call();
                },
              ),
              menuItem(
                Icons.bar_chart,
                'Analytics',
                active: activeAnalytics,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenAnalytics?.call();
                },
              ),

              // Tools
              sectionTitle('Tools'),
              menuItem(Icons.link, 'Catalogue Link'),
              menuItem(Icons.tune, 'Customize Store'),
              menuItem(Icons.auto_awesome_motion, 'AI Upload', pill: true),
              menuItem(Icons.chat_bubble_outline, 'WhatsApp'),
              menuItem(
                Icons.local_shipping_outlined,
                'Delivery',
                active: activeDelivery,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenDelivery?.call();
                },
              ),

              // Settings
              sectionTitle('Settings'),
              menuItem(
                Icons.store_mall_directory_outlined,
                'Store Settings',
                onTap: onClose,
              ),
              menuItem(Icons.receipt_long_outlined, 'Billing', onTap: onClose),
              menuItem(
                Icons.notifications_none_rounded,
                'Notifications',
                onTap: onClose,
              ),
              menuItem(Icons.settings_outlined, 'Settings', onTap: onClose),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    final confirmLogout = await showDialog<bool>(
                      context: context,
                      barrierDismissible: true,
                      builder: (dialogContext) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 32,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.logout,
                                  color: Color(0xFF98A2B3),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Are you sure you want to logout?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475467),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38004D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text(
                                    'Yes, logout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (confirmLogout != true) return;

                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logout failed. Please try again.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const SellerLoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
