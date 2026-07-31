import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';
import '../theme/app_theme.dart';
import '../utils/event_image_helper.dart';
import 'app_widgets.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');
    final now = DateTime.now();
    final spotsLeft = (event.capacity - event.registeredCount).clamp(0, event.capacity);
    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(now) &&
        event.endTime.isAfter(now);

    final progress = event.capacity > 0 ? (event.registeredCount / event.capacity).clamp(0.0, 1.0) : 0.0;
    final bannerUrl = getEventBannerUrl(event.category, event.bannerImageUrl, eventId: event.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: p.border),
        boxShadow: context.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: p.surfaceAlt),
                      errorWidget: (_, _, _) => Container(
                        color: p.surfaceAlt,
                        child: Icon(Icons.image_not_supported, color: p.textSecondary),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: isLive
                        ? const AppTag(
                            label: 'Live Now', color: Color(0xFF1E8E3E), icon: Icons.circle, solid: true)
                        : event.isFull
                            ? AppTag(label: 'Fully Booked', color: p.danger, solid: true)
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTag(label: event.category, color: p.info),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      event.title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: p.textPrimary, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetaRow(
                      icon: Icons.calendar_month_outlined,
                      text: dateFormat.format(event.startTime),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MetaRow(icon: Icons.location_on_outlined, text: event.venue),
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: p.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(event.isFull ? p.danger : p.accent),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event.isFull ? 'Fully booked' : '$spotsLeft spots left',
                          style: TextStyle(
                            fontSize: 12,
                            color: event.isFull ? p.danger : p.textSecondary,
                            fontWeight: event.isFull ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${event.registeredCount}/${event.capacity}',
                          style: TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                      ],
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

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 14, color: p.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
