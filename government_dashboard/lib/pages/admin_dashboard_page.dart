import 'package:flutter/material.dart';

/// Government admin dashboard showing complaints as a filterable list.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.warning_amber, color: Colors.orange),
            title: Text('Pothole on Main Street'),
            subtitle: Text('Infrastructure · High Priority'),
          ),
          ListTile(
            leading: Icon(Icons.lightbulb_outline, color: Colors.amber),
            title: Text('Broken Streetlight'),
            subtitle: Text('Utilities · Medium Priority'),
          ),
          ListTile(
            leading: Icon(Icons.water_drop, color: Colors.blue),
            title: Text('Water Supply Issue'),
            subtitle: Text('Utilities · High Priority'),
          ),
        ],
      ),
    );
  }
}
