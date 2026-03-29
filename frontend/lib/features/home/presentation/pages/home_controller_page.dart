import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:spotit/features/dashboard/presentation/pages/my_reports_page.dart';
import 'package:spotit/features/home/presentation/pages/home_feed_page.dart';
import 'package:spotit/features/home/presentation/widgets/report_issue_modal.dart';
import 'package:spotit/features/notifications/notification_badge.dart';
import 'package:spotit/features/notifications/presentation/pages/notifications_page.dart';
import 'package:spotit/features/profile/presentation/pages/profile_page.dart';
import 'package:spotit/core/theme/theme_switcher.dart';

// HomeControllerPage is the main shell of the citizen-side app.
// It owns the app bar, drawer, bottom nav bar, and four pages:
//   0 - Home Feed   (complaint list)
//   1 - Alerts      (notifications + chat)
//   2 - My Reports  (citizen's own complaints)
//   3 - Profile     (account settings)
//
// Pages live in an IndexedStack — switching tabs doesn't rebuild them,
// so scroll positions and loaded data are preserved.
class HomeControllerPage extends StatefulWidget {
  const HomeControllerPage({super.key});

  @override
  State<HomeControllerPage> createState() => _HomeControllerPageState();
}

class _HomeControllerPageState extends State<HomeControllerPage>
    with SingleTickerProviderStateMixin { // needed for AnimationController
  int _currentNavIndex = 0; // which tab is currently showing (0-3)

  // Required to get the screen position of the theme button for the
  // circular reveal animation origin point
  final GlobalKey _themeButtonKey = GlobalKey();

  // Home icon bounces gently when user has scrolled far down in the feed,
  // hinting they can tap Home to scroll back up
  late AnimationController _homeBounceController;
  late Animation<double> _homeBounceAnimation;
  bool _userHasScrolledDown = false;

  // This scroll controller is passed to HomeFeedPage so HomeControllerPage
  // can call animateTo(0) when the user taps the Home tab while already on it
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Bounce animation: scales the home icon between 100% and 115% size
    _homeBounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _homeBounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _homeBounceController, curve: Curves.easeInOut),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Listen to how many chat messages the citizen has unread.
      // The result drives the red badge count on the Alerts nav tab.
      NotificationBadge.startChatUnreadListener(user.uid);

      // Safety net: re-save the FCM push token in case it wasn't saved at startup
      // (e.g. the user wasn't logged in yet when the app first ran)
      _saveFcmTokenForUser(user);
    }
  }

  // Gets the device's FCM push token and stores it in Firestore so the
  // Cloud Function can send push notifications to this device
  Future<void> _saveFcmTokenForUser(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken(); // unique device push token
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token}); // saved on the user's profile doc
        debugPrint('FCM token re-saved for ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error re-saving FCM token: $e');
    }
  }

  @override
  void dispose() {
    NotificationBadge.stopChatUnreadListener(); // cancel the Firestore stream
    _homeBounceController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  // Called on every scroll frame from child pages.
  // Activates the home bounce animation when deep in the feed,
  // and deactivates it when the user scrolls back up.
  bool _onScrollNotification(ScrollNotification notification) {
    if (_currentNavIndex != 0) return false; // only care about the Home tab

    final offset = notification.metrics.pixels;
    if (offset > 200 && !_userHasScrolledDown) {
      _userHasScrolledDown = true;
      _homeBounceController.repeat(reverse: true); // loops the bounce
    } else if (offset <= 200 && _userHasScrolledDown) {
      _userHasScrolledDown = false;
      _homeBounceController.stop();
      _homeBounceController.animateTo(0, duration: const Duration(milliseconds: 200));
    }
    return false;
  }

  // Switches to a different bottom nav tab.
  // Special case: tapping Home while already on Home scrolls to the top.
  void _switchTab(int index) {
    if (index == 0 && _currentNavIndex == 0) {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    setState(() {
      _currentNavIndex = index;
      _userHasScrolledDown = false;
      _homeBounceController.stop();
      _homeBounceController.value = 0;
    });
  }

  // Called when a complaint is deleted from the My Reports detail view.
  // Returns the user to Home and shows a confirmation message.
  void _handleComplaintDeletedFromReports() {
    _switchTab(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for the next frame so the snack bar shows after the tab switch
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complaint deleted successfully'),
          backgroundColor: const Color(0xFFF9A825),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  // Pages are built once and kept alive by IndexedStack
  late final List<Widget> _pages = [
    HomeFeedPage(scrollController: _feedScrollController),
    const NotificationsPage(),
    MyReportsPage(onComplaintDeleted: _handleComplaintDeletedFromReports),
    ProfilePage(onSwitchTab: _switchTab),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: IndexedStack(
          index: _currentNavIndex, // shows only the selected page
          children: _pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: Builder(
        // Builder gives us a context that is a descendant of Scaffold,
        // which is required for Scaffold.of(context).openDrawer() to work
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded,
              color: isDark ? Colors.white.withAlpha(204) : Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Image.asset(
        'assets/images/home_logo.png',
        height: 36,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if the logo image file is missing
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Color(0xFFF9A825), size: 20),
              const SizedBox(width: 6),
              Text('SpotIT LK',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          );
        },
      ),
      centerTitle: true,
      actions: [
        // Theme toggle with a spinning icon transition and circular screen reveal
        IconButton(
          key: _themeButtonKey,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              // Icon spins + fades when theme changes
              return RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark), // different key triggers the animation
              color: isDark ? const Color(0xFFF9A825) : Colors.blueGrey,
            ),
          ),
          onPressed: () {
            // Find the button's center on screen to start the reveal from there
            final box = _themeButtonKey.currentContext?.findRenderObject() as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
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
                Image.asset('assets/images/home_logo.png', height: 32,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.location_on, color: Color(0xFFF9A825), size: 32)),
                const SizedBox(width: 12),
                Text('Menu',
                    style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.info_outline_rounded, 'About', 'Learn more about SpotIT', textColor,
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse('https://teamspotit.com.lk');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }),
          _buildDrawerItem(Icons.help_outline_rounded, 'Help & Feedback', 'Get help or send feedback', textColor, onTap: () {}),
          _buildDrawerItem(Icons.star_outline_rounded, 'Rate the App', 'Share your experience', textColor, onTap: () {}),
          _buildDrawerItem(Icons.mail_outline_rounded, 'Contact', 'Get in touch with us', textColor, onTap: () {}),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(children: [
              Text('SpotIT v1.0 • Report, Track, Solve',
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
      trailing: title == 'About'
          ? Icon(Icons.open_in_new, size: 16, color: textColor.withAlpha(102))
          : null,
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
        // SafeArea adds padding so the nav isn't hidden behind the phone's gesture bar
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0,
                  scaleAnimation: _homeBounceAnimation),
              // Only the Alerts icon has a dynamic badge — ValueListenableBuilder
              // means only this widget rebuilds when the count changes
              ValueListenableBuilder<int>(
                valueListenable: NotificationBadge.unreadCount,
                builder: (context, count, child) {
                  return _buildNavItem(icon: Icons.notifications_outlined,
                      label: 'Alerts', index: 1, badgeCount: count);
                },
              ),
              // Center gold "Report" button — opens the complaint submission modal
              GestureDetector(
                onTap: () => showReportIssueModal(context),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9A825),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF9A825).withAlpha(77),
                          blurRadius: 12, offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
              _buildNavItem(icon: Icons.article_outlined, label: 'Report', index: 2),
              _buildNavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  // Builds a single nav bar item with an icon, label, optional badge, and optional animation
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,              // 0 = no badge shown
    Animation<double>? scaleAnimation, // bounce animation (home tab only)
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _currentNavIndex == index;
    final inactiveColor = isDark ? Colors.white.withAlpha(102) : Colors.black38;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque, // makes the whole SizedBox tappable
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none, // badge can overflow the icon bounds
              children: [
                scaleAnimation != null
                    ? ScaleTransition(
                        scale: scaleAnimation,
                        child: Icon(icon,
                            color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                            size: 24))
                    : Icon(icon,
                        color: isActive ? const Color(0xFFF9A825) : inactiveColor,
                        size: 24),
                if (badgeCount > 0)
                  Positioned(
                    right: -6, top: -4, // position badge in upper-right corner
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
