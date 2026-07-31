/// Single shared taxonomy used for an organizer's club, an event's category,
/// and a student's interests — kept as one list so they can be compared for
/// equality/membership without name-mismatch bugs (e.g. filtering a feed by
/// interest requires event.category to use the exact same strings).
const List<String> kCampusCategories = [
  'Computing School',
  'Business School',
  'Student Council',
  'Engineering School',
  'School of Medicine',
  'Arts & Culture',
  'Sports Council',
  'Drama Society',
  'Music Society',
];

const List<String> kClubs = kCampusCategories;
