import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


import '../models/circle_modal.dart';
import '../models/event_model.dart';
import '../models/member_modal.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/create_event_modal.dart';
import '../widgets/event_detail_modal.dart';

class ActivitiesScreen extends StatefulWidget {
  final Circle circle;
  final Member currentMember;
  final List<Member> circleMembers;

  const ActivitiesScreen({
    super.key,
    required this.circle,
    required this.currentMember,
    required this.circleMembers,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<CircleEvent> _generateBirthdayEvents(List<Member> members, String currentMemberId) {
    final events = <CircleEvent>[];
    final now = DateTime.now();
    final oneYearFromNow = now.add(const Duration(days: 365));

    for (var member in members) {
      if (member.dob == null || member.id == currentMemberId) continue;

      try {
        final parts = member.dob!.split('/');
        if (parts.length != 3) continue;

        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);

        var birthdayThisYear = DateTime(now.year, month, day);

        if (birthdayThisYear.isBefore(now)) {
          birthdayThisYear = DateTime(now.year + 1, month, day);
        }

        if (birthdayThisYear.isBefore(oneYearFromNow)) {
          events.add(CircleEvent(
            id: 'birthday_${member.id}',
            title: '🎂 ${member.displayName}\'s Birthday',
            description: 'Wish them a happy birthday!',
            eventDate: birthdayThisYear,
            organizerId: '',
            organizerName: '',
            isBirthday: true,
            birthdayMemberId: member.id,
            createdAt: DateTime.now(),
          ));
        }
      } catch (e) {
        print('Error parsing birthday for ${member.fullName}: $e');
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activities'),
            Text(
              widget.circle.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTab(),
          _buildPastTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreateEventModal(
              circle: widget.circle,
              currentMember: widget.currentMember,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpcomingTab() {
    final authService = Provider.of<AuthService>(context, listen: false);

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!;
        final now = DateTime.now().toIso8601String();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('stakes')
              .doc(userData['stakeId'])
              .collection('wards')
              .doc(userData['wardId'])
              .collection('circles')
              .doc(widget.circle.id)
              .collection('events')
              .where('eventDate', isGreaterThanOrEqualTo: now)
              .orderBy('eventDate')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var events = snapshot.data!.docs
                .map((doc) => CircleEvent.fromFirestore(doc))
                .toList();

            // Add birthday events
            final birthdayEvents = _generateBirthdayEvents(
              widget.circleMembers,
              widget.currentMember.id,
            );
            events.addAll(birthdayEvents);
            events.sort((a, b) => a.eventDate.compareTo(b.eventDate));

            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming activities',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group recurring events
            final groupedEvents = _groupRecurringEvents(events);

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedEvents.length,
              itemBuilder: (context, index) {
                final group = groupedEvents[index];
                if (group.length == 1) {
                  return _buildEventCard(group.first, userData);
                } else {
                  return _buildRecurringEventGroup(group, userData);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPastTab() {
    final authService = Provider.of<AuthService>(context, listen: false);

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!;
        final now = DateTime.now().toIso8601String();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('stakes')
              .doc(userData['stakeId'])
              .collection('wards')
              .doc(userData['wardId'])
              .collection('circles')
              .doc(widget.circle.id)
              .collection('events')
              .where('eventDate', isLessThan: now)
              .orderBy('eventDate', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data!.docs
                .map((doc) => CircleEvent.fromFirestore(doc))
                .where((event) => !event.isBirthday)
                .toList();

            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No past activities',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                return _buildEventCard(events[index], userData);
              },
            );
          },
        );
      },
    );
  }

  List<List<CircleEvent>> _groupRecurringEvents(List<CircleEvent> events) {
    final groups = <List<CircleEvent>>[];
    final processed = <String>{};

    for (var event in events) {
      if (processed.contains(event.id)) continue;

      if (event.isRecurring && event.seriesId != null) {
        final seriesEvents = events
            .where((e) => e.seriesId == event.seriesId && !e.isBirthday)
            .toList();

        if (seriesEvents.length > 1) {
          groups.add(seriesEvents);
          for (var e in seriesEvents) {
            processed.add(e.id);
          }
        } else {
          groups.add([event]);
          processed.add(event.id);
        }
      } else {
        groups.add([event]);
        processed.add(event.id);
      }
    }

    return groups;
  }

  Widget _buildRecurringEventGroup(List<CircleEvent> events, Map<String, dynamic> userData) {
    final firstEvent = events.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.greenPrimary.withOpacity(0.2),
          child: const Icon(Icons.event_repeat, color: AppTheme.greenPrimary),
        ),
        title: Text(
          firstEvent.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${events.length} occurrences'),
        children: events.map((event) => _buildEventListTile(event, userData)).toList(),
      ),
    );
  }

  Widget _buildEventCard(CircleEvent event, Map<String, dynamic> userData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildEventListTile(event, userData),
    );
  }

  Widget _buildEventListTile(CircleEvent event, Map<String, dynamic> userData) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: event.isBirthday
            ? AppTheme.rosePrimary.withOpacity(0.2)
            : AppTheme.greenPrimary.withOpacity(0.2),
        child: Icon(
          event.isBirthday ? Icons.cake : Icons.event,
          color: event.isBirthday ? AppTheme.rosePrimary : AppTheme.greenPrimary,
        ),
      ),
      title: Text(
        event.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateFormat.format(event.eventDate)),
          if (event.eventTime != null)
            Text(timeFormat.format(event.eventDateTime)),
          if (event.location != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(event.location!)),
              ],
            ),
        ],
      ),
      trailing: event.isToday
          ? Chip(
        label: const Text('Today', style: TextStyle(fontSize: 12)),
        backgroundColor: AppTheme.amberPrimary.withOpacity(0.3),
      )
          : null,
      onTap: event.isBirthday
          ? null
          : () {
        showDialog(
          context: context,
          builder: (context) => EventDetailModal(
            event: event,
            circle: widget.circle,
            currentMember: widget.currentMember,
            userData: userData,
          ),
        );
      },
    );
  }
}