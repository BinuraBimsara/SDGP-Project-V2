import 'package:flutter/material.dart';

/// Home page where citizens can view reports and vote on them.
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Pothole on Main Street'),
            subtitle: const Text('Infrastructure'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up),
                  onPressed: () {},
                ),
                const Text('45'),
                IconButton(
                  icon: const Icon(Icons.thumb_down),
                  onPressed: () {},
                ),
                const Text('2'),
              ],
            ),
          ),
          ListTile(
            title: const Text('Broken Streetlight'),
            subtitle: const Text('Utilities'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up),
                  onPressed: () {},
                ),
                const Text('32'),
                IconButton(
                  icon: const Icon(Icons.thumb_down),
                  onPressed: () {},
                ),
                const Text('1'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
