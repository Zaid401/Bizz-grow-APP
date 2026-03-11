import 'package:flutter/material.dart';

class TopHeaderSliver extends StatelessWidget {
  const TopHeaderSliver({
    super.key,
    required this.backgroundColor,
    required this.accent,
    required this.unreadNotifications,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    required this.logoUrl,
    required this.initials,
  });

  final Color backgroundColor;
  final Color accent;
  final int unreadNotifications;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final String? logoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    return SliverAppBar(
      pinned: true,
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: onMenuPressed,
        icon: const Icon(Icons.menu_rounded, color: Color(0xFF4A3A59)),
      ),
      actions: [
        IconButton(
          onPressed: onNotificationsPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF4A3A59),
              ),
              if (unreadNotifications > 0)
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
                      unreadNotifications > 9
                          ? '9+'
                          : unreadNotifications.toString(),
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
            backgroundColor: hasLogo ? Colors.transparent : accent,
            backgroundImage: hasLogo ? NetworkImage(logoUrl!) : null,
            child: hasLogo
                ? null
                : Text(
                    initials,
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
}
