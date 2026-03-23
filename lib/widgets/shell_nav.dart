import 'package:flutter/material.dart';

enum ShellTab {
  dashboard,
  orders,
  products,
  posBilling,
  analytics,
  vendors,
  customers,
  delivery,
  storeSettings,
  aiUpload,
}

extension ShellTabIndex on ShellTab {
  int get index => switch (this) {
    ShellTab.dashboard => 0,
    ShellTab.orders => 1,
    ShellTab.products => 2,
    ShellTab.posBilling => 3,
    ShellTab.analytics => 4,
    ShellTab.vendors => 5,
    ShellTab.customers => 6,
    ShellTab.delivery => 7,
    ShellTab.storeSettings => 8,
    ShellTab.aiUpload => 9,
  };
}

class ShellNav extends InheritedWidget {
  const ShellNav({
    super.key,
    required this.index,
    required this.setIndex,
    required super.child,
  });

  final int index;
  final ValueChanged<int> setIndex;

  static ShellNav? maybeOf(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<ShellNav>();
    return element?.widget as ShellNav?;
  }

  static void switchTo(
    BuildContext context,
    ShellTab tab, {
    VoidCallback? fallback,
  }) {
    final shell = maybeOf(context);
    if (shell == null) {
      fallback?.call();
      return;
    }
    shell.setIndex(tab.index);
  }

  static Future<void> switchAfterDrawerClose(
    BuildContext context,
    ShellTab tab, {
    VoidCallback? closeDrawer,
    Duration delay = kThemeAnimationDuration,
    VoidCallback? fallback,
  }) async {
    final shell = maybeOf(context);
    if (shell == null) {
      fallback?.call();
      return;
    }
    closeDrawer?.call();
    await Future<void>.delayed(delay);
    shell.setIndex(tab.index);
  }

  @override
  bool updateShouldNotify(ShellNav oldWidget) => index != oldWidget.index;
}
