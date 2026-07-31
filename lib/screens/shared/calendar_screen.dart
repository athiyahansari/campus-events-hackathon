import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final bool embedded;
  const CalendarScreen({super.key, this.embedded = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.publicEventFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'We could not load the calendar. Check your connection and try again.',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;

          final selectedDayEvents = events
              .where((e) => DateUtils.isSameDay(e.startTime, _selectedDate))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          final eventDates = events
              .map((e) => DateTime(e.startTime.year, e.startTime.month, e.startTime.day))
              .toSet();

          return CustomScrollView(
            slivers: [
              if (!widget.embedded)
                SliverAppBar(
                  floating: true,
                  title: Row(
                    children: [
                      Icon(Icons.calendar_month, color: p.accent),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Events Calendar'),
                    ],
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('MMMM yyyy').format(_focusedMonth),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'Previous month',
                              color: p.textSecondary,
                              onPressed: () => setState(() {
                                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.today),
                              color: p.accent,
                              tooltip: 'Jump to today',
                              onPressed: () => setState(() {
                                _selectedDate = DateTime.now();
                                _focusedMonth = DateTime.now();
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              tooltip: 'Next month',
                              color: p.textSecondary,
                              onPressed: () => setState(() {
                                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildCalendarGrid(eventDates),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: p.accent, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: p.textPrimary),
                        ),
                      ),
                      AppTag(
                        label: '${selectedDayEvents.length} '
                            'event${selectedDayEvents.length == 1 ? '' : 's'}',
                        color: p.info,
                      ),
                    ],
                  ),
                ),
              ),

              if (selectedDayEvents.isEmpty)
                const SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.event_busy,
                    title: 'Nothing scheduled',
                    message: 'No events on this day. Try another date on the calendar above.',
                  ),
                )
              else
                SliverList.builder(
                  itemCount: selectedDayEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedDayEvents[index];
                    return EventCard(
                      event: event,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                      ),
                    );
                  },
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarGrid(Set<DateTime> eventDates) {
    final p = context.palette;
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfWeek = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;

    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        Row(
          children: weekDays
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: p.textSecondary),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth + firstDayOfWeek,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < firstDayOfWeek) return const SizedBox.shrink();

            final day = index - firstDayOfWeek + 1;
            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final isSelected = DateUtils.isSameDay(date, _selectedDate);
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final hasEvent = eventDates.contains(DateTime(date.year, date.month, date.day));

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? p.accent
                        : (isToday ? p.accent.withValues(alpha: 0.12) : p.surfaceAlt),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: isToday && !isSelected ? Border.all(color: p.accent) : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (isToday ? p.accent : p.textPrimary),
                          fontSize: 13,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : p.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
