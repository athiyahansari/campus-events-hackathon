import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';

import '../utils/event_image_helper.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd · HH:mm');
    final spotsLeft = event.capacity - event.registeredCount;
    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(DateTime.now().add(const Duration(hours: 1))) &&
        event.endTime.isAfter(DateTime.now());
    
    final progress = event.capacity > 0 ? (event.registeredCount / event.capacity).clamp(0.0, 1.0) : 0.0;
    final bannerUrl = getEventBannerUrl(event.category, event.bannerImageUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image Area
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                            const SizedBox(width: 6),
                            const Text('Live Now', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  if (event.isFull && !isLive)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Fully Booked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                ],
              ),
              
              // Bottom Details Area
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(event.category, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 14, color: Colors.black45),
                        const SizedBox(width: 6),
                        Text(dateFormat.format(event.startTime), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.pinkAccent),
                        const SizedBox(width: 6),
                        Expanded(child: Text(event.venue, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Capacity Progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(event.isFull ? Colors.red : Colors.blueAccent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.isFull ? 'Fully Booked' : '$spotsLeft spots left',
                      style: TextStyle(
                        fontSize: 11,
                        color: event.isFull ? Colors.red : Colors.black54,
                        fontWeight: event.isFull ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
