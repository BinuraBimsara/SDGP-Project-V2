import 'package:flutter/material.dart';

/// A simple bar-chart-style widget for dashboard data.
class DashboardChart extends StatelessWidget {
  final Map<String, double> data;
  final String title;

  const DashboardChart({
    Key? key,
    required this.data,
    this.title = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...data.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(entry.key)),
                    Expanded(
                      flex: 5,
                      child: LinearProgressIndicator(
                        value: entry.value / 100,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.value.toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
