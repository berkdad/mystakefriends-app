import 'package:flutter/material.dart';
import '../models/member_modal.dart';
import '../theme/app_theme.dart';

class MemberProfileModal extends StatelessWidget {
  final Member member;

  const MemberProfileModal({
    super.key,
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header with gradient
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            // Profile Picture
            Transform.translate(
              offset: const Offset(0, -60),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppTheme.rosePrimary.withOpacity(0.2),
                  backgroundImage: member.profilePicUrl != null
                      ? NetworkImage(member.profilePicUrl!)
                      : null,
                  child: member.profilePicUrl == null
                      ? Text(
                    member.fullName.isNotEmpty ? member.fullName[0] : '?',
                    style: const TextStyle(fontSize: 40),
                  )
                      : null,
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Center(
                      child: Column(
                        children: [
                          Text(
                            member.fullName,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (member.preferredName != null && member.preferredName!.isNotEmpty)
                            Text(
                              '"${member.preferredName}"',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // About Me
                    if (member.aboutMe != null && member.aboutMe!.isNotEmpty) ...[
                      _buildSection(
                        context,
                        'About Me',
                        member.aboutMe!,
                      ),
                    ],

                    // Contact
                    if (member.email != null || member.phone != null || member.address != null) ...[
                      _buildSectionHeader(context, 'Contact'),
                      if (member.email != null)
                        _buildInfoRow(context, Icons.email, 'Email', member.email!),
                      if (member.phone != null)
                        _buildInfoRow(context, Icons.phone, 'Phone', member.phone!),
                      if (member.address != null)
                        _buildInfoRow(context, Icons.location_on, 'Address', member.address!),
                      const SizedBox(height: 16),
                    ],

                    // Personal Details
                    if (member.dob != null || member.maritalStatus != null || member.ethnicity != null) ...[
                      _buildSectionHeader(context, 'Personal'),
                      if (member.dob != null) ...[
                        _buildInfoRow(
                          context,
                          Icons.cake,
                          'Birthday',
                          member.age != null ? '${member.dob} (${member.age} years old)' : member.dob!,
                        ),
                      ],
                      if (member.maritalStatus != null)
                        _buildInfoRow(
                          context,
                          Icons.favorite,
                          'Marital Status',
                          member.maritalStatus![0].toUpperCase() + member.maritalStatus!.substring(1),
                        ),
                      if (member.ethnicity != null)
                        _buildInfoRow(context, Icons.public, 'Cultural Background', member.ethnicity!),
                      const SizedBox(height: 16),
                    ],

                    // Family
                    if (member.spouseName != null || member.numChildren != null) ...[
                      _buildSectionHeader(context, 'Family'),
                      if (member.spouseName != null)
                        _buildInfoRow(context, Icons.favorite, 'Spouse', member.spouseName!),
                      if (member.numChildren != null && int.tryParse(member.numChildren!) != null && int.parse(member.numChildren!) > 0) ...[
                        _buildInfoRow(
                          context,
                          Icons.child_care,
                          'Children',
                          '${member.numChildren} ${int.parse(member.numChildren!) == 1 ? "child" : "children"}',
                        ),
                        if (member.childrenNames != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Text(member.childrenNames!, style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // Professional
                    if (member.occupation != null || member.employer != null || member.education != null) ...[
                      _buildSectionHeader(context, 'Professional & Education'),
                      if (member.occupation != null)
                        _buildInfoRow(context, Icons.work, 'Occupation', member.occupation!),
                      if (member.employer != null)
                        _buildInfoRow(context, Icons.business, 'Employer', member.employer!),
                      if (member.education != null)
                        _buildInfoRow(context, Icons.school, 'Education', member.education!),
                      const SizedBox(height: 16),
                    ],

                    // Hobbies & Interests
                    if (member.hobbies != null || member.interests != null || member.talents != null) ...[
                      _buildSectionHeader(context, 'Hobbies & Interests'),
                      if (member.hobbies != null)
                        _buildInfoRow(context, Icons.hiking, 'Hobbies', member.hobbies!),
                      if (member.interests != null)
                        _buildInfoRow(context, Icons.star, 'Interests', member.interests!),
                      if (member.talents != null)
                        _buildInfoRow(context, Icons.emoji_events, 'Talents', member.talents!),
                      const SizedBox(height: 16),
                    ],

                    // Spiritual Journey
                    if (member.spiritualJourney != null || member.testimony != null) ...[
                      _buildSectionHeader(context, 'Spiritual Journey'),
                      if (member.spiritualJourney != null)
                        _buildSection(context, 'My Journey', member.spiritualJourney!),
                      if (member.favoriteScripture != null)
                        _buildSection(context, 'Favorite Scripture', member.favoriteScripture!),
                      if (member.testimony != null)
                        _buildSection(context, 'Testimony', member.testimony!),
                      if (member.callings != null)
                        _buildInfoRow(context, Icons.church, 'Current Callings', member.callings!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.rosePrimary,
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.rosePrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}