# Government Dashboard

This project is a Flutter application designed to serve as a Government Dashboard. It provides a user-friendly interface for citizens to report issues and for administrators to manage those reports effectively.

## Features

- **Home Page**: Citizens can view reports and vote on them.
- **Admin Dashboard**: Administrators can manage complaints, view statistics, and filter reports.
- **Real-time Data**: The application uses streams to provide real-time updates on reports and statistics.
- **Responsive Design**: The layout adapts to different screen sizes, ensuring usability on both mobile and tablet devices.

## Project Structure

```
government_dashboard
├── lib
│   ├── main.dart
│   ├── app.dart
│   ├── models
│   │   ├── dashboard_item.dart
│   │   ├── citizen_report.dart
│   │   └── government_stat.dart
│   ├── streams
│   │   ├── dashboard_stream.dart
│   │   ├── reports_stream.dart
│   │   └── stats_stream.dart
│   ├── data
│   │   ├── mock_dashboard_data.dart
│   │   ├── mock_reports_data.dart
│   │   └── mock_stats_data.dart
│   ├── pages
│   │   ├── home_page.dart
│   │   └── admin_dashboard_page.dart
│   ├── widgets
│   │   ├── stat_card.dart
│   │   ├── report_tile.dart
│   │   ├── dashboard_chart.dart
│   │   └── nav_drawer.dart
│   ├── routes
│   │   └── app_routes.dart
│   └── utils
│       └── constants.dart
├── test
│   ├── streams
│   │   ├── dashboard_stream_test.dart
│   │   └── stats_stream_test.dart
│   ├── pages
│   │   ├── home_page_test.dart
│   │   └── admin_dashboard_page_test.dart
│   └── widgets
│       └── stat_card_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Setup Instructions

1. **Clone the repository**:
   ```
   git clone <repository-url>
   ```

2. **Navigate to the project directory**:
   ```
   cd government_dashboard
   ```

3. **Install dependencies**:
   ```
   flutter pub get
   ```

4. **Run the application**:
   ```
   flutter run
   ```

## Future Enhancements

- Implement user authentication for citizens and administrators.
- Add push notifications for new reports or updates.
- Enhance the admin dashboard with more analytics and reporting features.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.