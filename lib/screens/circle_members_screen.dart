import 'package:flutter/material.dart';

import '../models/member_modal.dart';
import '../theme/app_theme.dart';
import '../widgets/member_profile_modal.dart';

class CircleMembersScreen extends StatelessWidget {
  final List<Member> members;
  final String circleName;

  const CircleMembersScreen({
    super.key,
    required this.members,
    required this.circleName,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Circle Members'),
            Text(
              circleName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: members.isEmpty
            ? Center(
          child: Text(
            'No members in this circle',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
        )
            : GridView.builder(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildMemberCard(context, member);
          },
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, Member member) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => MemberProfileModal(member: member),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.rosePrimary.withOpacity(0.2),
              backgroundImage: member.profilePicUrl != null
                  ? NetworkImage(member.profilePicUrl!)
                  : null,
              child: member.profilePicUrl == null
                  ? Text(
                member.fullName.isNotEmpty ? member.fullName[0] : '?',
                style: const TextStyle(
                  fontSize: 32,
                  color: AppTheme.rosePrimary,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
            const SizedBox(height: 12),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                member.fullName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Preferred Name
            if (member.preferredName != null && member.preferredName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '"${member.preferredName}"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),

            // About Me Preview
            if (member.aboutMe != null && member.aboutMe!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  member.aboutMe!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const Spacer(),

            // Birthday Indicator
            if (member.isBirthdayToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.amberPrimary.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cake, size: 16, color: AppTheme.rosePrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Birthday Today!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.rosePrimary,
                      ),
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