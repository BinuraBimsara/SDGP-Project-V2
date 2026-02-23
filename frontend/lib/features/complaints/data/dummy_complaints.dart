import 'package:spotit/features/complaints/data/models/complaint_model.dart';

class DummyComplaints {
  static List<Complaint> getComplaints() {
    return [
      Complaint(
        id: 'dummy_1',
        title: 'Overflowing garbage bins',
        description:
            'Multiple garbage bins have not been collected for over a week. Strong odor affecting nearby residents.',
        category: 'Waste',
        imageUrl:
            'https://images.unsplash.com/photo-1605600659908-0ef719419d41?w=600&h=400&fit=crop',
        status: 'Pending',
        upvoteCount: 18,
        commentCount: 0,
        timestamp: DateTime(2025, 11, 6),
        authorId: 'user_001',
        locationName: 'Park Avenue, Block 5',
        isUpvoted: false,
      ),
      Complaint(
        id: 'dummy_2',
        title: 'Broken streetlight',
        description:
            'Streetlight has been non-functional for two weeks, creating safety concerns for pedestrians at night.',
        category: 'Lighting',
        imageUrl:
            'https://media.istockphoto.com/id/1445183752/photo/broken-street-lamp.jpg?s=2048x2048&w=is&k=20&c=NmQluJ6hShwNp_0Luvp9udwWwIclqIc2whirABtnduU=',
        status: 'Pending',
        upvoteCount: 31,
        commentCount: 0,
        timestamp: DateTime(2025, 11, 4),
        authorId: 'user_002',
        locationName: 'Elm Street near School',
        isUpvoted: false,
      ),
      Complaint(
        id: 'dummy_3',
        title: 'Large pothole on Main Street',
        description:
            'Deep pothole causing traffic issues and potential damage to vehicles. Located near the intersection with Oak Avenue.',
        category: 'Pothole',
        imageUrl:
            'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=600&h=400&fit=crop',
        status: 'In Progress',
        upvoteCount: 24,
        commentCount: 1,
        timestamp: DateTime(2025, 11, 1),
        authorId: 'user_003',
        locationName: 'Main Street & Oak Avenue',
        isUpvoted: false,
      ),
      Complaint(
        id: 'dummy_4',
        title: 'Cracked sidewalk causing trip hazard',
        description:
            'Significant cracks in the sidewalk creating dangerous conditions for pedestrians, especially elderly residents.',
        category: 'Infrastructure',
        imageUrl:
            'https://ichef.bbci.co.uk/news/480/cpsprodpb/1522/live/650818f0-d33d-11ef-b37c-2d6cb9a2e3c0.jpg.webp',
        status: 'Resolved',
        upvoteCount: 12,
        commentCount: 1,
        timestamp: DateTime(2025, 10, 28),
        authorId: 'user_004',
        locationName: 'Cedar Lane',
        isUpvoted: false,
      ),
      Complaint(
        id: 'dummy_5',
        title: 'Illegal dumping near river bank',
        description:
            'Large quantities of construction waste dumped illegally near the river, posing environmental hazard to the waterway.',
        category: 'Waste',
        imageUrl:
            'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=600&h=400&fit=crop',
        status: 'Pending',
        upvoteCount: 42,
        commentCount: 3,
        timestamp: DateTime(2025, 11, 5),
        authorId: 'user_005',
        locationName: 'River Road, Section B',
        isUpvoted: false,
      ),
    ];
  }
}
