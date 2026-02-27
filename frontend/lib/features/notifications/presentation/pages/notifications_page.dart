import 'package:flutter/material.dart';

class _NotificationItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String time;
  final bool isUnread;

  _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.time,
    this.isUnread = false,
  });
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final dummyNotifications = [
      _NotificationItem(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF4CAF50), // Green shade
        title: 'Report Status Updated',
        description:
            'Your report "Large pothole on Main Street" has been marked as In Progress',
        time: '1h ago',
        isUnread: true,
      ),
      _NotificationItem(
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFF90CAF9), // Light blue shade
        title: 'New Comment',
        description: 'A government official commented on your report',
        time: '2h ago',
        isUnread: true,
      ),
      _NotificationItem(
        icon: Icons.arrow_upward,
        iconColor: const Color(0xFF4CAF50), // Green shade
        title: 'Report Upvoted',
        description: 'Your report received 5 new upvotes',
        time: '1d ago',
        isUnread: false,
      ),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2 unread',
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details List
            Expanded(
              child: ListView.builder(
                itemCount: dummyNotifications.length,
                itemBuilder: (context, index) {
                  final item = dummyNotifications[index];

                  // Card Styling Colors Based on Theme
                  final cardBgColor =
                      isDark ? const Color(0xFF1E2124) : Colors.white;
                  final iconBgColor = isDark
                      ? const Color(0xFF2B2D31)
                      : Colors.blueGrey.shade50;
                  final borderSide = item.isUnread
                      ? const BorderSide(color: Color(0xFF4CAF50), width: 1.5)
                      : BorderSide(
                          color: isDark
                              ? Colors.transparent
                              : Colors.grey.shade300,
                          width: 1.0);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.fromBorderSide(borderSide),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon portion
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.iconColor,
                            size: 24.0,
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        // Content portion
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (item.isUnread)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4CAF50),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: subtitleColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14.0,
                                    color: subtitleColor,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    item.time,
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
