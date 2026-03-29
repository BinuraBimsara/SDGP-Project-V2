import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotit/features/auth/data/services/auth_service.dart';
import 'package:spotit/features/auth/presentation/pages/get_started_page.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_dashboard_page.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_profile_page.dart';
import 'package:spotit/features/notifications/notification_badge.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_alerts_page.dart';
import 'package:spotit/core/theme/theme_switcher.dart';

// GovHomeControllerPage is the main shell for the GOVERNMENT OFFICIAL side of the app.
// It mirrors HomeControllerPage but with only 3 tabs:
//   0 - Dashboard  (complaint categories and stats overview)
//   1 - Alerts     (chat messages from citizens — with unread badge)
//   2 - Profile    (official's account info and logout)
//
// Unlike the citizen controller, this uses a simple switch/case for pages
// (not IndexedStack) so that switching tabs always reloads the page with fresh data.
class GovHomeControllerPage extends StatefulWidget {
  const GovHomeControllerPage({super.key});

  @override
  State<GovHomeControllerPage> createState() => _GovHomeControllerPageState();
}

class _GovHomeControllerPageState extends State<GovHomeControllerPage> {
  int _currentNavIndex = 0; // which tab is active

  // UniqueKey forces the current page to rebuild completely when switching tabs.
  // This ensures the dashboard reloads fresh data when the official comes back to it.
  Key _pageKey = UniqueKey();

  // Used to locate the theme button for the circular reveal animation origin
  final GlobalKey _themeButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Listen to unread chat messages from citizens.
      // The count drives the red badge on the Alerts tab.
      NotificationBadge.startOfficialChatUnreadListener(user.uid);
    }
  }

  @override
  void dispose() {
    NotificationBadge.stopChatUnreadListener(); // cancel the Firestore stream
    super.dispose();
  }

  // Switches to a different tab. A new UniqueKey forces the page to rebuild.
  void _switchTab(int index) {
    if (index != _currentNavIndex) {
      setState(() {
        _currentNavIndex = index;
        _pageKey = UniqueKey(); // fresh key = fresh page build = fresh Firestore fetch
      });
    }
  }

  // Returns the correct page widget for the current tab index
  Widget _currentPage() {
    switch (_currentNavIndex) {
      case 0:
        return GovDashboardPage(key: _pageKey); // complaint categories grid
      case 1:
        return GovAlertsPage(key: _pageKey);    // citizen chat sessions
      case 2:
        return GovProfilePage(key: _pageKey);   // official's profile
      default:
        return GovDashboardPage(key: _pageKey);
    }
  }

  // Shows a confirmation dialog before signing the official out.
  // fromDrawer: true means we also pop the drawer before logging out.
  Future<void> _handleLogout({bool fromDrawer = false}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show a confirm dialog — we don't want accidental logouts
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 22),
            const SizedBox(width: 8),
            Text('Log Out',
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), // user chose No
            child: Text('No',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true), // user chose Yes
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350), // red logout button
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // user cancelled
    if (!mounted) return;

    if (fromDrawer && Navigator.canPop(context)) {
      Navigator.pop(context); // close the drawer first
    }

    await AuthService().signOut(); // call Firebase Auth sign out
    if (!mounted) return;

    // Navigate to the Get Started page and remove all previous routes.
    // pushAndRemoveUntil ensures the user can't press back to get back to the dashboard.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedPage()),
      (route) => false, // remove all routes under the new one
    );
  }

  // Opens the SpotIT website in the phone's default browser
  Future<void> _openAboutWebsite() async {
    const url = 'https://teamspotit.com.lk/';
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      // Show an error if the browser couldn't be opened
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _currentPage(), // rebuilds entirely on tab switch (no IndexedStack)
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: Builder(
        // Builder creates a new context that is a child of Scaffold,
        // required for Scaffold.of(context).openDrawer() to work correctly
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded,
              color: isDark ? Colors.white.withAlpha(204) : Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield, color: Color(0xFFF9A825), size: 22), // shield = official
          const SizedBox(width: 8),
          Text('SpotIT Official',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ],
      ),
      centerTitle: true,
      actions: [
        // Theme toggle button — same circular reveal animation as citizen side
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
            final box = _themeButtonKey.currentContext?.findRenderObject() as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(
                  Offset(box.size.width / 2, box.size.height / 2));
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
              border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(51))),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFFF9A825), size: 32),
                const SizedBox(width: 12),
                Text('Official Menu',
                    style: TextStyle(
                        color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', 'View all reports', textColor,
              onTap: () {
                Navigator.pop(context);
                _switchTab(0); // go to the dashboard tab
              }),
          _buildDrawerItem(Icons.info_outline_rounded, 'About', 'Learn more about SpotIT', textColor,
              onTap: () {
                Navigator.pop(context);
                _openAboutWebsite();
              }),
          _buildDrawerItem(Icons.help_outline_rounded, 'Help & Feedback', 'Get help or send feedback', textColor,
              onTap: () => Navigator.pop(context)),
          const Spacer(),
          // Logout option at the bottom, styled in red to indicate a destructive action
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(13),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            ),
            title: Text('Sign Out',
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
            onTap: () => _handleLogout(fromDrawer: true),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(children: [
              Text('SpotIT Official v1.0',
                  style: TextStyle(color: textColor.withAlpha(128), fontSize: 12)),
              const SizedBox(height: 4),
              Text('© 2026 Team SpotIT',
                  style: TextStyle(color: textColor.withAlpha(128), fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String subtitle, Color textColor,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: textColor.withAlpha(13), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFFF9A825), size: 20),
      ),
      title: Text(title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(color: textColor.withAlpha(153), fontSize: 12)),
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
              color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(20)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
              // Alerts tab has a live unread count badge from the chat stream
              ValueListenableBuilder<int>(
                valueListenable: NotificationBadge.unreadCount,
                builder: (context, count, child) {
                  return _buildNavItem(icon: Icons.notifications_outlined,
                      label: 'Alerts', index: 1, badgeCount: count);
                },
              ),
              _buildNavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 2),
            ],
          ),
        ),
      ),
    );
  }

  // Builds a single nav bar item with optional badge for unread counts
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0, // shows a red dot with count when > 0
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _currentNavIndex == index;
    final inactiveColor = isDark ? Colors.white.withAlpha(102) : Colors.black38;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72, // wider than citizen tabs since there are only 3
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                    size: 24),
                if (badgeCount > 0)
                  Positioned(
                    right: -6, top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF5350), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$badgeCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
