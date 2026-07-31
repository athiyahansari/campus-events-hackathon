String getEventBannerUrl(String category, String? customUrl) {
  if (customUrl != null &&
      customUrl.trim().isNotEmpty &&
      !customUrl.contains('via.placeholder.com') &&
      !customUrl.contains('placeholder.com')) {
    return customUrl.trim();
  }

  switch (category) {
    case 'Computing School':
    case 'Engineering School':
    case 'Academic':
      return 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&q=80';
    case 'Business School':
      return 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800&q=80';
    case 'Student Council':
      return 'https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=800&q=80';
    case 'School of Medicine':
      return 'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?w=800&q=80';
    case 'Arts & Culture':
    case 'Drama Society':
      return 'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=800&q=80';
    case 'Sports Council':
      return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&q=80';
    case 'Music Society':
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80';
    default:
      return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80';
  }
}
