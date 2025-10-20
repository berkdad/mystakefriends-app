import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/circle_modal.dart';
import '../models/event_model.dart';
import '../models/member_modal.dart';
import '../theme/app_theme.dart';

class EventDetailModal extends StatelessWidget {
  final CircleEvent event;
  final Circle circle;
  final Member currentMember;
  final Map<String, dynamic> userData;

  const EventDetailModal({
    super.key,
    required this.event,
    required this.circle,
    required this.currentMember,
    required this.userData,
  });

  Future<void> _deleteEvent(BuildContext context, {bool deleteAll = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(deleteAll
            ? 'Delete all events in this series?'
            : 'Delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final eventsRef = FirebaseFirestore.instance
          .collection('stakes')
          .doc(userData['stakeId'])
          .collection('wards')
          .doc(userData['wardId'])
          .collection('circles')
          .doc(circle.id)
          .collection('events');

      if (deleteAll && event.isRecurring && event.seriesId != null) {
        // Delete all events in series
        final seriesEvents = await eventsRef
            .where('seriesId', isEqualTo: event.seriesId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in seriesEvents.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } else {
        // Delete single event
        await eventsRef.doc(event.id).delete();
      }

      Navigator.pop(context); // Close detail modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteAll ? 'Series deleted' : 'Event deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final isOrganizer = event.organizerId == currentMember.id;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Image or Header
            if (event.imageUrl != null)
              Stack(
                children: [
                  Image.network(
                    event.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.greenPrimary.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Event Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date & Time
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Date',
                      dateFormat.format(event.eventDate),
                    ),

                    if (event.eventTime != null)
                      _buildInfoRow(
                        Icons.access_time,
                        'Time',
                        timeFormat.format(event.eventDateTime),
                      ),

                    // Location
                    if (event.location != null && event.location!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on,
                        'Location',
                        event.location!,
                      ),

                    // Organizer
                    _buildInfoRow(
                      Icons.person,
                      'Organized by',
                      event.organizerName,
                    ),

                    // Recurring info
                    if (event.isRecurring)
                      _buildInfoRow(
                        Icons.event_repeat,
                        'Recurring',
                        _getRecurrenceDescription(event.recurrencePattern),
                      ),

                    // Description
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer with actions
            if (isOrganizer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (event.isRecurring)
                      TextButton.icon(
                        onPressed: () => _showDeleteOptions(context),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _deleteEvent(context),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.greenPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRecurrenceDescription(RecurrencePattern? pattern) {
    if (pattern == null) return 'Recurring';

    String freq = '';
    switch (pattern.frequency) {
      case RecurrenceFrequency.daily:
        freq = 'Daily';
        break;
      case RecurrenceFrequency.weekly:
        freq = 'Weekly';
        break;
      case RecurrenceFrequency.monthly:
        freq = 'Monthly';
        break;
      case RecurrenceFrequency.yearly:
        freq = 'Yearly';
        break;
      default:
        freq = '';
    }

    if (pattern.interval > 1) {
      freq = 'Every ${pattern.interval} ${freq.toLowerCase()}';
    }

    if (pattern.endDate != null) {
      freq += ' until ${DateFormat('MMM d, yyyy').format(pattern.endDate!)}';
    }

    return freq;
  }

  void _showDeleteOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Do you want to delete just this event or all events in the series?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close options dialog
              _deleteEvent(context, deleteAll: false);
            },
            child: const Text('This Event Only'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close options dialog
              _deleteEvent(context, deleteAll: true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('All in Series'),
          ),
        ],
      ),
    );
  }
}