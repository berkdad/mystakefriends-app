import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/circle_modal.dart';
import '../models/event_model.dart';
import '../models/member_modal.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CreateEventModal extends StatefulWidget {
  final Circle circle;
  final Member currentMember;

  const CreateEventModal({
    super.key,
    required this.circle,
    required this.currentMember,
  });

  @override
  State<CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends State<CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _imageUrl;
  bool _isUploading = false;
  bool _isCreating = false;

  // Recurrence
  bool _isRecurring = false;
  RecurrenceFrequency _frequency = RecurrenceFrequency.weekly;
  int _interval = 1;
  DateTime? _endDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child(
        'circles/${widget.circle.id}/events/${timestamp}_${image.name}',
      );

      final uploadTask = storageRef.putFile(File(image.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _imageUrl = downloadUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData();

      if (userData == null) throw Exception('User data not found');

      DateTime eventDateTime = _selectedDate!;
      String? eventTime;

      if (_selectedTime != null) {
        eventDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        eventTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
      }

      final eventsRef = _firestore
          .collection('stakes')
          .doc(userData['stakeId'])
          .collection('wards')
          .doc(userData['wardId'])
          .collection('circles')
          .doc(widget.circle.id)
          .collection('events');

      if (_isRecurring && _endDate != null) {
        // Create recurring events
        final seriesId = const Uuid().v4();
        final recurrencePattern = RecurrencePattern(
          frequency: _frequency,
          interval: _interval,
          endDate: _endDate,
        );

        final occurrences = _generateOccurrences(eventDateTime, recurrencePattern);

        final batch = _firestore.batch();
        for (var occurrence in occurrences) {
          final docRef = eventsRef.doc();
          batch.set(docRef, {
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'location': _locationController.text.trim(),
            'eventDate': occurrence.toIso8601String(),
            'eventTime': eventTime,
            'imageUrl': _imageUrl,
            'organizerId': widget.currentMember.id,
            'organizerName': widget.currentMember.displayName,
            'isRecurring': true,
            'seriesId': seriesId,
            'recurrencePattern': recurrencePattern.toMap(),
            'isBirthday': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      } else {
        // Create single event
        await eventsRef.add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'location': _locationController.text.trim(),
          'eventDate': eventDateTime.toIso8601String(),
          'eventTime': eventTime,
          'imageUrl': _imageUrl,
          'organizerId': widget.currentMember.id,
          'organizerName': widget.currentMember.displayName,
          'isRecurring': false,
          'isBirthday': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating event: $e')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  List<DateTime> _generateOccurrences(DateTime start, RecurrencePattern pattern) {
    final occurrences = <DateTime>[];
    DateTime current = start;

    while (current.isBefore(pattern.endDate!) || current.isAtSameMomentAs(pattern.endDate!)) {
      occurrences.add(current);

      switch (pattern.frequency) {
        case RecurrenceFrequency.daily:
          current = current.add(Duration(days: pattern.interval));
          break;
        case RecurrenceFrequency.weekly:
          current = current.add(Duration(days: 7 * pattern.interval));
          break;
        case RecurrenceFrequency.monthly:
          current = DateTime(current.year, current.month + pattern.interval, current.day);
          break;
        case RecurrenceFrequency.yearly:
          current = DateTime(current.year + pattern.interval, current.month, current.day);
          break;
        case RecurrenceFrequency.none:
          break;
      }

      if (occurrences.length > 365) break; // Safety limit
    }

    return occurrences;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
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
                  const Icon(Icons.event, color: AppTheme.greenPrimary),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload
                      if (_imageUrl != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrl!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  onPressed: () => setState(() => _imageUrl = null),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickImage,
                          icon: _isUploading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.image),
                          label: Text(_isUploading ? 'Uploading...' : 'Add Image (Optional)'),
                        ),

                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Event Title *',
                          hintText: 'e.g., Game Night',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Tell us about the event...',
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      // Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, color: AppTheme.greenPrimary),
                        title: Text(_selectedDate == null
                            ? 'Select Date *'
                            : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                      ),

                      // Time
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time, color: AppTheme.greenPrimary),
                        title: Text(_selectedTime == null
                            ? 'Select Time (Optional)'
                            : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Location
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'e.g., Smith\'s Home or 123 Main St',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Recurring checkbox
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recurring Event'),
                        value: _isRecurring,
                        onChanged: (value) => setState(() => _isRecurring = value ?? false),
                      ),

                      if (_isRecurring) ...[
                        // Frequency
                        DropdownButtonFormField<RecurrenceFrequency>(
                          value: _frequency,
                          decoration: const InputDecoration(labelText: 'Frequency'),
                          items: const [
                            DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text('Daily')),
                            DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text('Weekly')),
                            DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                            DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _frequency = value);
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // End Date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event, color: AppTheme.greenPrimary),
                          title: Text(_endDate == null
                              ? 'Select End Date *'
                              : 'Until ${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? (_selectedDate ?? DateTime.now()).add(const Duration(days: 90)),
                              firstDate: _selectedDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createEvent,
                    child: _isCreating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Create Event'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}