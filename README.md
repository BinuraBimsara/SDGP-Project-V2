THis is our file structure to be used as the basic skeleton of our program
├── .gitignore
├── README.md
├── firebase.json
├── firestore.rules
├── storage.rules
├── backend/
│   ├── README.md
│   └── seed_data.dart
├── frontend/
│   ├── .gitignore
│   ├── .metadata
│   ├── README.md
│   ├── analysis_options.yaml
│   ├── analyze_out.txt
│   ├── pubspec.yaml
│   ├── pubspec.lock
│   ├── android/
│   ├── ios/
│   ├── macos/
│   ├── web/
│   ├── test/
│   └── lib/
│       ├── main.dart
│       ├── firebase_options.dart
│       ├── core/
│       │   └── services/
│       │       └── location_service.dart
│       └── features/
│           ├── auth/
│           │   ├── data/
│           │   │   └── services/
│           │   │       └── auth_service.dart
│           │   └── presentation/
│           │       └── pages/
│           │           ├── login_page.dart
│           │           └── signup_dialog.dart
│           ├── complaints/
│           │   └── data/
│           │       ├── dummy_complaints.dart
│           │       ├── models/
│           │       │   └── complaint_model.dart
│           │       └── repositories/
│           └── home/
│               └── presentation/
│                   ├── pages/
│                   │   └── complaint_detail_page.dart
│                   └── widgets/
│                       └── complaint_card.dart
└── functions/
