import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
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

    final body = StreamBuilder<List<EventModel>>(
      stream: firestore.publicEventFeed(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading events: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!;
        
        // Find events on selected date
        final selectedDayEvents = events.where((e) {
          return e.startTime.year == _selectedDate.year &&
              e.startTime.month == _selectedDate.month &&
              e.startTime.day == _selectedDate.day;
        }).toList();

        // Dates in current focused month that have events
        final eventDates = events.map((e) => DateTime(e.startTime.year, e.startTime.month, e.startTime.day)).toSet();

        return CustomScrollView(
          slivers: [
            if (!widget.embedded)
              const SliverAppBar(
                backgroundColor: Color(0xFF1E2F4D),
                title: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Events Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                floating: true,
                pinned: false,
              ),
            
            // Month Header & Navigation
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.today, color: Colors.blueAccent),
                          tooltip: 'Today',
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime.now();
                              _focusedMonth = DateTime.now();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Calendar Grid Widget
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildCalendarGrid(eventDates),
              ),
            ),

            // Selected Day Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Color(0xFF3366FF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Events on ${DateFormat('EEE, MMM d, yyyy').format(_selectedDate)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedDayEvents.length} Event${selectedDayEvents.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Events List for Selected Day
            if (selectedDayEvents.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No events scheduled for this day.', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = selectedDayEvents[index];
                    return EventCard(
                      event: event,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                      ),
                    );
                  },
                  childCount: selectedDayEvents.length,
                ),
              ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 64)),
          ],
        );
      },
    );

    if (widget.embedded) return Scaffold(backgroundColor: const Color(0xFFF8F9FA), body: body);
    return Scaffold(backgroundColor: const Color(0xFFF8F9FA), body: body);
  }

  Widget _buildCalendarGrid(Set<DateTime> eventDates) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfWeek = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;

    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Weekday Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        
        // Days Grid
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
            if (index < firstDayOfWeek) {
              return const SizedBox.shrink();
            }

            final day = index - firstDayOfWeek + 1;
            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final isSelected = DateUtils.isSameDay(date, _selectedDate);
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final hasEvent = eventDates.contains(DateTime(date.year, date.month, date.day));

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3366FF)
                      : (isToday ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: isToday && !isSelected ? Border.all(color: const Color(0xFF3366FF)) : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isToday ? const Color(0xFF3366FF) : Colors.black87),
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
                            color: isSelected ? Colors.white : const Color(0xFF3366FF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
