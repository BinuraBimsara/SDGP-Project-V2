import 'package:flutter/material.dart';
import 'package:spotit/features/auth/data/services/auth_service.dart';
import 'package:spotit/features/auth/presentation/pages/login_page.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_dashboard_page.dart';
import 'package:spotit/features/notifications/notification_badge.dart';
import 'package:spotit/features/notifications/presentation/pages/notifications_page.dart';
import 'package:spotit/features/profile/presentation/pages/profile_page.dart';
import 'package:spotit/core/theme/theme_switcher.dart';

/// The main shell for the government official view.
/// Contains the appbar, bottom navigation, and page switching.
class GovHomeControllerPage extends StatefulWidget {
  const GovHomeControllerPage({super.key});

  @override
  State<GovHomeControllerPage> createState() => _GovHomeControllerPageState();
}

class _GovHomeControllerPageState extends State<GovHomeControllerPage> {
  int _currentNavIndex = 0;
  Key _pageKey = UniqueKey();
  final GlobalKey _themeButtonKey = GlobalKey();

  void _switchTab(int index) {
    if (index != _currentNavIndex) {
      setState(() {
        _currentNavIndex = index;
        _pageKey = UniqueKey();
      });
    }
  }

  Widget _currentPage() {
    switch (_currentNavIndex) {
      case 0:
        return GovDashboardPage(key: _pageKey);
      case 1:
        return NotificationsPage(key: _pageKey);
      case 2:
        return ProfilePage(key: _pageKey, onSwitchTab: _switchTab);
      default:
        return GovDashboardPage(key: _pageKey);
    }
  }

  Future<void> _handleLogout() async {
    // Close the drawer first so the modal route doesn't block navigation
    Navigator.pop(context);
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _currentPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white.withAlpha(204) : Colors.black87,
          ),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield, color: Color(0xFFF9A825), size: 22),
          const SizedBox(width: 8),
          Text(
            'SpotIT Official',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          key: _themeButtonKey,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              color: isDark ? const Color(0xFFF9A825) : Colors.blueGrey,
            ),
          ),
          onPressed: () {
            final box = _themeButtonKey.currentContext?.findRenderObject()
                as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(
                Offset(box.size.width / 2, box.size.height / 2),
              );
              ThemeSwitcher.switchTheme(context, position);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.withAlpha(51)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFFF9A825), size: 32),
                const SizedBox(width: 12),
                Text(
                  'Official Menu',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            Icons.dashboard_outlined,
            'Dashboard',
            'View all reports',
            textColor,
            onTap: () {
              Navigator.pop(context);
              _switchTab(0);
            },
          ),
          _buildDrawerItem(
            Icons.info_outline_rounded,
            'About',
            'Learn more about SpotIT',
            textColor,
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            Icons.help_outline_rounded,
            'Help & Feedback',
            'Get help or send feedback',
            textColor,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Logout
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(13),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            ),
            title: Text(
              'Sign Out',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            onTap: _handleLogout,
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'SpotIT Official v1.0',
                  style: TextStyle(
                    color: textColor.withAlpha(128),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 Team SpotIT',
                  style: TextStyle(
                    color: textColor.withAlpha(128),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    String subtitle,
    Color textColor, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFF9A825), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: textColor.withAlpha(153), fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(20),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                index: 0,
              ),
              ValueListenableBuilder<int>(
                valueListenable: NotificationBadge.unreadCount,
                builder: (context, count, child) {
                  return _buildNavItem(
                    icon: Icons.notifications_outlined,
                    label: 'Alerts',
                    index: 1,
                    badgeCount: count,
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _currentNavIndex == index;
    final inactiveColor = isDark ? Colors.white.withAlpha(102) : Colors.black38;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF5350),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
