import 'package:flutter/material.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: isDark
                  ? Colors.white.withAlpha(100)
                  : Colors.grey.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withAlpha(200) : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track the status of your complaints here.',
              style: TextStyle(
                color: isDark ? Colors.white.withAlpha(150) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
