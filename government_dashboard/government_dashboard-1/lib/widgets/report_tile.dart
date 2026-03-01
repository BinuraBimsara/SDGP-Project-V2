import 'package:flutter/material.dart';

import '../models/citizen_report.dart';

/// A list-tile widget for a single citizen report with vote buttons.
class ReportTile extends StatelessWidget {
  final CitizenReport report;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;

  const ReportTile({
    Key? key,
    required this.report,
    this.onUpvote,
    this.onDownvote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(report.title),
      subtitle: Text(report.description),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.thumb_up),
            onPressed: onUpvote,
          ),
          Text('${report.upvotes}'),
          IconButton(
            icon: const Icon(Icons.thumb_down),
            onPressed: onDownvote,
          ),
          Text('${report.downvotes}'),
        ],
      ),
    );
  }
}
