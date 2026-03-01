import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'utils/constants.dart';

/// Root widget for the Government Dashboard application.
class GovernmentDashboardApp extends StatelessWidget {
  const GovernmentDashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
