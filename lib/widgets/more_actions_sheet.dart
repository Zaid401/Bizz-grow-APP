import 'package:flutter/material.dart';

enum MoreActionsModule {
  dashboard,
  posBilling,
  orders,
  products,
  customers,
  analytics,
  aiUpload,
  catalogueLink,
  vendors,
}

// ── Palette ────────────────────────────────────────────────────────────────────
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
}

Future<void> showMoreActionsSheet({
  required BuildContext context,
  required VoidCallback onOpenDashboard,
  required VoidCallback onOpenOrders,
  required VoidCallback onOpenProducts,
  required VoidCallback onOpenPosBilling,
  required VoidCallback onOpenAnalytics,
  MoreActionsModule? activeModule,
  VoidCallback? onAddProduct,
  VoidCallback? onOpenAiUpload,
  VoidCallback? onOpenCatalogueLink,
  VoidCallback? onOpenVendors,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _MoreActionsSheet(
      onOpenDashboard: onOpenDashboard,
      onOpenOrders: onOpenOrders,
      onOpenProducts: onOpenProducts,
      onOpenPosBilling: onOpenPosBilling,
      onOpenAnalytics: onOpenAnalytics,
      activeModule: activeModule,
      onAddProduct: onAddProduct,
      onOpenAiUpload: onOpenAiUpload,
      onOpenCatalogueLink: onOpenCatalogueLink,
      onOpenVendors: onOpenVendors,
    ),
  );
}

class _MoreActionsSheet extends StatelessWidget {
  const _MoreActionsSheet({
    required this.onOpenDashboard,
    required this.onOpenOrders,
    required this.onOpenProducts,
    required this.onOpenPosBilling,
    required this.onOpenAnalytics,
    this.activeModule,
    this.onAddProduct,
    this.onOpenAiUpload,
    this.onOpenCatalogueLink,
    this.onOpenVendors,
  });

  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenPosBilling;
  final VoidCallback onOpenAnalytics;
  final MoreActionsModule? activeModule;
  final VoidCallback? onAddProduct;
  final VoidCallback? onOpenAiUpload;
  final VoidCallback? onOpenCatalogueLink;
  final VoidCallback? onOpenVendors;

  void _handle(BuildContext ctx, VoidCallback? onTap) {
    Navigator.of(ctx).pop();
    onTap?.call();
  }

  // ── Quick action data ──────────────────────────────────────────────────────
  static const _quickActions = [
    _QuickData(
      icon: Icons.add_box_rounded,
      label: 'Add Product',
      gradient: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      softBg: Color(0xFFDBEAFE),
    ),
    _QuickData(
      icon: Icons.auto_awesome_rounded,
      label: 'AI Upload',
      gradient: [Color(0xFFD97706), Color(0xFFB45309)],
      softBg: Color(0xFFFEF3C7),
    ),
    _QuickData(
      icon: Icons.point_of_sale_rounded,
      label: 'POS Billing',
      gradient: [Color(0xFF059669), Color(0xFF047857)],
      softBg: Color(0xFFD1FAE5),
    ),
    _QuickData(
      icon: Icons.bar_chart_rounded,
      label: 'Analytics',
      gradient: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
      softBg: Color(0xFFEDE9FE),
    ),
  ];

  // ── Module data ────────────────────────────────────────────────────────────
  List<_ModuleData> _modules() => [
    _ModuleData(
      Icons.grid_view_rounded,
      'Dashboard',
      MoreActionsModule.dashboard,
      onOpenDashboard,
    ),
    _ModuleData(
      Icons.point_of_sale_rounded,
      'POS Billing',
      MoreActionsModule.posBilling,
      onOpenPosBilling,
    ),
    _ModuleData(
      Icons.shopping_bag_rounded,
      'Orders',
      MoreActionsModule.orders,
      onOpenOrders,
    ),
    _ModuleData(
      Icons.inventory_2_rounded,
      'Products',
      MoreActionsModule.products,
      onOpenProducts,
    ),
    _ModuleData(
      Icons.auto_awesome_rounded,
      'AI Upload',
      MoreActionsModule.aiUpload,
      onOpenAiUpload,
    ),
    _ModuleData(
      Icons.link_rounded,
      'Catalogue',
      MoreActionsModule.catalogueLink,
      onOpenCatalogueLink,
    ),
    _ModuleData(
      Icons.bar_chart_rounded,
      'Analytics',
      MoreActionsModule.analytics,
      onOpenAnalytics,
    ),
    _ModuleData(
      Icons.storefront_rounded,
      'Vendors',
      MoreActionsModule.vendors,
      onOpenVendors,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final modules = _modules();

    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ─────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _C.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── Header ─────────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.accentLight, _C.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _C.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.apps_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _C.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Quick action icons row ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickBtn(
                    context,
                    _quickActions[0],
                    onAddProduct ?? onOpenProducts,
                  ),
                  _buildQuickBtn(context, _quickActions[1], onOpenAiUpload),
                  _buildQuickBtn(context, _quickActions[2], onOpenPosBilling),
                  _buildQuickBtn(context, _quickActions[3], onOpenAnalytics),
                ],
              ),

              const SizedBox(height: 22),

              // ── Section label ───────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'All Modules',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _C.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_C.divider, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Module grid ────────────────────────────────────────────────
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: modules
                        .map(
                          (m) => SizedBox(
                            width: w,
                            child: _buildModuleChip(context, m),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick action button ───────────────────────────────────────────────────
  Widget _buildQuickBtn(
    BuildContext context,
    _QuickData d,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: () => _handle(context, onTap),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: d.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: d.gradient.last.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(d.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            d.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Module chip ───────────────────────────────────────────────────────────
  Widget _buildModuleChip(BuildContext context, _ModuleData m) {
    final isActive = activeModule == m.module;

    return GestureDetector(
      onTap: () => _handle(context, m.onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _C.accentSoft : _C.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? _C.accentMid : _C.divider,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _C.accent.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isActive ? _C.accent.withOpacity(0.12) : _C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? _C.accentMid : _C.divider),
              ),
              child: Icon(
                m.icon,
                size: 16,
                color: isActive ? _C.accent : _C.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? _C.accent : _C.textPrimary,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _C.accentLight,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────
class _QuickData {
  const _QuickData({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.softBg,
  });
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color softBg;
}

class _ModuleData {
  const _ModuleData(this.icon, this.label, this.module, this.onTap);
  final IconData icon;
  final String label;
  final MoreActionsModule module;
  final VoidCallback? onTap;
}
