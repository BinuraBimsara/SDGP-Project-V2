import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/admin_dashboard_page.dart';

/// Centralised route definitions for the app.
class AppRoutes {
  static const String home = '/';
  static const String admin = '/admin';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomePage(),
        admin: (context) => const AdminDashboardPage(),
      };
}
