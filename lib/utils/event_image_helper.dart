String getEventBannerUrl(String category, String? customUrl, {String? eventId}) {
  if (customUrl != null &&
      customUrl.trim().isNotEmpty &&
      !customUrl.contains('via.placeholder.com') &&
      !customUrl.contains('placeholder.com')) {
    return customUrl.trim();
  }

  final seed = (eventId ?? category).hashCode.abs();

  final Map<String, List<String>> categoryImages = {
    'Computing School': [
      'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&q=80',
      'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&q=80',
      'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&q=80',
      'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&q=80',
    ],
    'Engineering School': [
      'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=800&q=80',
      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&q=80',
      'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=800&q=80',
    ],
    'Business School': [
      'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800&q=80',
      'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=800&q=80',
      'https://images.unsplash.com/photo-1542744801-30d45d44840d?w=800&q=80',
    ],
    'Student Council': [
      'https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=800&q=80',
      'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800&q=80',
      'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800&q=80',
    ],
    'School of Medicine': [
      'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?w=800&q=80',
      'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&q=80',
      'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=800&q=80',
    ],
    'Arts & Culture': [
      'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=800&q=80',
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&q=80',
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
    ],
    'Sports Council': [
      'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&q=80',
      'https://images.unsplash.com/photo-1517649763962-0c623266010b?w=800&q=80',
      'https://images.unsplash.com/photo-1526676037777-05a232554f77?w=800&q=80',
    ],
    'Music Society': [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=80',
    ],
    // Was missing, so Drama Society events fell through to the generic pool.
    'Drama Society': [
      'https://images.unsplash.com/photo-1503095396549-807759245b35?w=800&q=80',
      'https://images.unsplash.com/photo-1507924538820-ede94a04019d?w=800&q=80',
      'https://images.unsplash.com/photo-1470019693664-1d202d2c0907?w=800&q=80',
    ],
  };

  final list = categoryImages[category] ?? [
    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&q=80',
    'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800&q=80',
  ];

  return list[seed % list.length];
}
