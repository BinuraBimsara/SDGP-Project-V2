import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF9C27B0).withAlpha(50),
              child: const Icon(
                Icons.person_rounded,
                size: 50,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome, User!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profile settings coming soon',
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
