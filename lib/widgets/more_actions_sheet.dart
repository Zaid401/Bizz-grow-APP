import 'package:flutter/material.dart';

enum MoreActionsModule {
  dashboard,
  posBilling,
  orders,
  products,
  analytics,
  aiUpload,
  catalogueLink,
  vendors,
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
    builder: (sheetContext) {
      void handleTap(VoidCallback? onTap) {
        Navigator.of(sheetContext).pop();
        onTap?.call();
      }

      Widget quickAction(
        IconData icon,
        String label,
        Color color,
        VoidCallback? onTap,
      ) {
        return GestureDetector(
          onTap: () => handleTap(onTap),
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A3A59),
                ),
              ),
            ],
          ),
        );
      }

      Widget moduleChip(
        IconData icon,
        String label,
        VoidCallback? onTap, {
        bool highlighted = false,
      }) {
        final bg = highlighted
            ? const Color(0xFFEAE3F5)
            : const Color(0xFFF6F2FB);
        final fg = highlighted
            ? const Color(0xFF4D0E7F)
            : const Color(0xFF2C1937);
        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => handleTap(onTap),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: fg,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C1937),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    quickAction(
                      Icons.add,
                      'Add Product',
                      const Color(0xFF2F6BFF),
                      onAddProduct ?? onOpenProducts,
                    ),
                    quickAction(
                      Icons.auto_awesome_motion,
                      'AI Upload',
                      const Color(0xFFF39C12),
                      onOpenAiUpload,
                    ),
                    quickAction(
                      Icons.point_of_sale,
                      'POS Billing',
                      const Color(0xFF2ECC71),
                      onOpenPosBilling,
                    ),
                    quickAction(
                      Icons.bar_chart,
                      'Analytics',
                      const Color(0xFF8E54E9),
                      onOpenAnalytics,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'All Modules',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A4C8A),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          [
                                moduleChip(
                                  Icons.grid_view_rounded,
                                  'Dashboard',
                                  onOpenDashboard,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.dashboard,
                                ),
                                moduleChip(
                                  Icons.point_of_sale,
                                  'POS Billing',
                                  onOpenPosBilling,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.posBilling,
                                ),
                                moduleChip(
                                  Icons.shopping_cart_outlined,
                                  'Orders',
                                  onOpenOrders,
                                  highlighted:
                                      activeModule == MoreActionsModule.orders,
                                ),
                                moduleChip(
                                  Icons.inventory_2_outlined,
                                  'Products',
                                  onOpenProducts,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.products,
                                ),
                                moduleChip(
                                  Icons.auto_awesome_motion,
                                  'AI Upload',
                                  onOpenAiUpload,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.aiUpload,
                                ),
                                moduleChip(
                                  Icons.link,
                                  'Catalogue Link',
                                  onOpenCatalogueLink,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.catalogueLink,
                                ),
                                moduleChip(
                                  Icons.bar_chart,
                                  'Analytics',
                                  onOpenAnalytics,
                                  highlighted:
                                      activeModule ==
                                      MoreActionsModule.analytics,
                                ),
                                moduleChip(
                                  Icons.storefront_outlined,
                                  'Vendors',
                                  onOpenVendors,
                                  highlighted:
                                      activeModule == MoreActionsModule.vendors,
                                ),
                              ]
                              .map(
                                (chip) =>
                                    SizedBox(width: itemWidth, child: chip),
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
    },
  );
}
