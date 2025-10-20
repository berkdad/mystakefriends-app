import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/member_modal.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final Member member;

  const ProfileScreen({
    super.key,
    required this.member,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _preferredNameController;
  late TextEditingController _aboutMeController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _dobController;
  late TextEditingController _anniversaryController;
  late TextEditingController _ethnicityController;
  late TextEditingController _spouseNameController;
  late TextEditingController _numChildrenController;
  late TextEditingController _childrenNamesController;
  late TextEditingController _occupationController;
  late TextEditingController _employerController;
  late TextEditingController _educationController;
  late TextEditingController _hobbiesController;
  late TextEditingController _interestsController;
  late TextEditingController _talentsController;
  late TextEditingController _favoriteBooksController;
  late TextEditingController _favoriteMusicController;
  late TextEditingController _spiritualJourneyController;
  late TextEditingController _favoriteScriptureController;
  late TextEditingController _testimonyController;
  late TextEditingController _callingsController;
  late TextEditingController _personalGoalsController;
  late TextEditingController _familyGoalsController;
  late TextEditingController _spiritualGoalsController;

  String? _maritalStatus;
  String? _profilePicUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _preferredNameController = TextEditingController(text: widget.member.preferredName);
    _aboutMeController = TextEditingController(text: widget.member.aboutMe);
    _phoneController = TextEditingController(text: widget.member.phone);
    _addressController = TextEditingController(text: widget.member.address);
    _dobController = TextEditingController(text: widget.member.dob);
    _anniversaryController = TextEditingController(text: widget.member.anniversary);
    _ethnicityController = TextEditingController(text: widget.member.ethnicity);
    _spouseNameController = TextEditingController(text: widget.member.spouseName);
    _numChildrenController = TextEditingController(text: widget.member.numChildren);
    _childrenNamesController = TextEditingController(text: widget.member.childrenNames);
    _occupationController = TextEditingController(text: widget.member.occupation);
    _employerController = TextEditingController(text: widget.member.employer);
    _educationController = TextEditingController(text: widget.member.education);
    _hobbiesController = TextEditingController(text: widget.member.hobbies);
    _interestsController = TextEditingController(text: widget.member.interests);
    _talentsController = TextEditingController(text: widget.member.talents);
    _favoriteBooksController = TextEditingController(text: widget.member.favoriteBooks);
    _favoriteMusicController = TextEditingController(text: widget.member.favoriteMusic);
    _spiritualJourneyController = TextEditingController(text: widget.member.spiritualJourney);
    _favoriteScriptureController = TextEditingController(text: widget.member.favoriteScripture);
    _testimonyController = TextEditingController(text: widget.member.testimony);
    _callingsController = TextEditingController(text: widget.member.callings);
    _personalGoalsController = TextEditingController(text: widget.member.personalGoals);
    _familyGoalsController = TextEditingController(text: widget.member.familyGoals);
    _spiritualGoalsController = TextEditingController(text: widget.member.spiritualGoals);

    _maritalStatus = widget.member.maritalStatus;
    _profilePicUrl = widget.member.profilePicUrl;
  }

  @override
  void dispose() {
    _preferredNameController.dispose();
    _aboutMeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _anniversaryController.dispose();
    _ethnicityController.dispose();
    _spouseNameController.dispose();
    _numChildrenController.dispose();
    _childrenNamesController.dispose();
    _occupationController.dispose();
    _employerController.dispose();
    _educationController.dispose();
    _hobbiesController.dispose();
    _interestsController.dispose();
    _talentsController.dispose();
    _favoriteBooksController.dispose();
    _favoriteMusicController.dispose();
    _spiritualJourneyController.dispose();
    _favoriteScriptureController.dispose();
    _testimonyController.dispose();
    _callingsController.dispose();
    _personalGoalsController.dispose();
    _familyGoalsController.dispose();
    _spiritualGoalsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfilePic() async {
    print('📸 Opening image picker dialog');

    // Show dialog to choose camera or gallery
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.rosePrimary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.bluePrimary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      print('❌ No source selected');
      return;
    }

    print('✅ Source selected: $source');

    try {
      print('📷 Attempting to pick image...');
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        print('❌ No image selected');
        return;
      }

      print('✅ Image picked: ${image.path}');
      print('📁 File size: ${await image.length()} bytes');

      if (!mounted) return;
      setState(() => _isUploading = true);

      print('☁️ Uploading to Firebase Storage...');
      final storageRef = _storage.ref().child('profilePics/${widget.member.id}');

      print('📤 Starting upload...');
      final uploadTask = storageRef.putFile(File(image.path));

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask;
      print('✅ Upload complete!');

      print('🔗 Getting download URL...');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Download URL: $downloadUrl');

      if (!mounted) return;
      setState(() {
        _profilePicUrl = downloadUrl;
        _isUploading = false;
      });

      print('✅ Profile picture updated in UI');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded!')),
      );
    } catch (e, stackTrace) {
      print('❌ Error uploading picture: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading picture: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData();

      if (userData == null) {
        throw Exception('User data not found');
      }

      await _firestore
          .collection('stakes')
          .doc(userData['stakeId'])
          .collection('wards')
          .doc(userData['wardId'])
          .collection('members')
          .doc(widget.member.id)
          .update({
        'preferredName': _preferredNameController.text.trim(),
        'aboutMe': _aboutMeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'dob': _dobController.text.trim(),
        'maritalStatus': _maritalStatus,
        'anniversary': _anniversaryController.text.trim(),
        'ethnicity': _ethnicityController.text.trim(),
        'spouseName': _spouseNameController.text.trim(),
        'numChildren': _numChildrenController.text.trim(),
        'childrenNames': _childrenNamesController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'employer': _employerController.text.trim(),
        'education': _educationController.text.trim(),
        'hobbies': _hobbiesController.text.trim(),
        'interests': _interestsController.text.trim(),
        'talents': _talentsController.text.trim(),
        'favoriteBooks': _favoriteBooksController.text.trim(),
        'favoriteMusic': _favoriteMusicController.text.trim(),
        'spiritualJourney': _spiritualJourneyController.text.trim(),
        'favoriteScripture': _favoriteScriptureController.text.trim(),
        'testimony': _testimonyController.text.trim(),
        'callings': _callingsController.text.trim(),
        'personalGoals': _personalGoalsController.text.trim(),
        'familyGoals': _familyGoalsController.text.trim(),
        'spiritualGoals': _spiritualGoalsController.text.trim(),
        'profilePicUrl': _profilePicUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        controller.text = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit My Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.rosePrimary.withOpacity(0.2),
                      backgroundImage: _profilePicUrl != null
                          ? NetworkImage(_profilePicUrl!)
                          : null,
                      child: _profilePicUrl == null
                          ? Text(
                        widget.member.fullName.isNotEmpty
                            ? widget.member.fullName[0]
                            : '?',
                        style: const TextStyle(fontSize: 40),
                      )
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: AppTheme.rosePrimary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _isUploading ? null : _pickAndUploadProfilePic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Read-only fields
              Center(
                child: Column(
                  children: [
                    Text(
                      widget.member.fullName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.member.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Name and email cannot be changed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.amberAccent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Basic Information
              _buildSectionHeader('Basic Information'),
              _buildTextField(
                controller: _preferredNameController,
                label: 'Preferred Name / Nickname',
                hint: 'What you like to be called',
              ),
              _buildTextField(
                controller: _aboutMeController,
                label: 'About Me',
                hint: 'Tell others a little about yourself...',
                maxLines: 3,
              ),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
              ),
              _buildDateField(
                controller: _dobController,
                label: 'Date of Birth',
              ),
              _buildDropdownField(
                label: 'Marital Status',
                value: _maritalStatus,
                items: const ['single', 'married', 'widowed', 'divorced'],
                onChanged: (value) => setState(() => _maritalStatus = value),
              ),
              _buildTextField(
                controller: _ethnicityController,
                label: 'Cultural Background',
              ),

              const SizedBox(height: 24),

              // Family Information
              _buildSectionHeader('Family Information'),
              _buildTextField(
                controller: _spouseNameController,
                label: 'Spouse Name',
              ),
              _buildDateField(
                controller: _anniversaryController,
                label: 'Anniversary',
              ),
              _buildTextField(
                controller: _numChildrenController,
                label: 'Number of Children',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _childrenNamesController,
                label: 'Children\'s Names',
                hint: 'e.g., John, Mary, David',
              ),

              const SizedBox(height: 24),

              // Professional & Education
              _buildSectionHeader('Professional & Education'),
              _buildTextField(
                controller: _occupationController,
                label: 'Occupation',
              ),
              _buildTextField(
                controller: _employerController,
                label: 'Employer',
              ),
              _buildTextField(
                controller: _educationController,
                label: 'Education',
              ),

              const SizedBox(height: 24),

              // Hobbies & Interests
              _buildSectionHeader('Hobbies & Interests'),
              _buildTextField(
                controller: _hobbiesController,
                label: 'Hobbies',
                hint: 'e.g., Hiking, Photography, Cooking',
              ),
              _buildTextField(
                controller: _interestsController,
                label: 'Interests',
                hint: 'e.g., Travel, History, Technology',
              ),
              _buildTextField(
                controller: _talentsController,
                label: 'Talents',
                hint: 'e.g., Piano, Public Speaking, Gardening',
              ),
              _buildTextField(
                controller: _favoriteBooksController,
                label: 'Favorite Books',
              ),
              _buildTextField(
                controller: _favoriteMusicController,
                label: 'Favorite Music',
              ),

              const SizedBox(height: 24),

              // Spiritual Journey
              _buildSectionHeader('Spiritual Journey'),
              _buildTextField(
                controller: _spiritualJourneyController,
                label: 'My Spiritual Journey',
                hint: 'Share your conversion story or spiritual experiences...',
                maxLines: 3,
              ),
              _buildTextField(
                controller: _favoriteScriptureController,
                label: 'Favorite Scripture',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _testimonyController,
                label: 'Testimony',
                hint: 'Share your testimony...',
                maxLines: 3,
              ),
              _buildTextField(
                controller: _callingsController,
                label: 'Current Callings',
              ),

              const SizedBox(height: 24),

              // Goals & Aspirations
              _buildSectionHeader('Goals & Aspirations'),
              _buildTextField(
                controller: _personalGoalsController,
                label: 'Personal Goals',
                hint: 'What are you working towards personally?',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _familyGoalsController,
                label: 'Family Goals',
                hint: 'Goals for your family...',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _spiritualGoalsController,
                label: 'Spiritual Goals',
                hint: 'Your spiritual aspirations...',
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Profile'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.rosePrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(controller),
          ),
        ),
        readOnly: true,
        onTap: () => _selectDate(controller),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item[0].toUpperCase() + item.substring(1)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}