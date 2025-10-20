import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/circle_modal.dart';
import '../models/event_modal.dart';
import '../models/member_modal.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'activities_screen.dart';
import 'profile_screen.dart';
import '../widgets/event_detail_modal.dart';
import 'circle_members_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Member? _currentMember;
  Circle? _myCircle;
  List<Member> _circleMembers = [];
  List<ChatMessage> _recentChats = [];
  List<CircleEvent> _upcomingEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  // Replace your _initializeDashboard method with this:
  Future<void> _initializeDashboard() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final fcmService = Provider.of<FCMService>(context, listen: false);

    try {
      // Get user data
      final userData = await authService.getUserData();
      if (userData == null) {
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final stakeId = userData['stakeId'] as String?;
      final wardId = userData['wardId'] as String?;

      if (stakeId == null || wardId == null) {
        setState(() {
          _errorMessage = 'Not assigned to a ward yet';
          _isLoading = false;
        });
        return;
      }

      // Initialize FCM and refresh tokens
      await fcmService.initialize();
      await fcmService.refreshToken(authService.currentUser!.uid);

      // Get member profile
      final memberDoc = await authService.getMemberProfile(
        stakeId,
        wardId,
        authService.currentUser!.email!,
      );

      if (memberDoc == null) {
        setState(() {
          _errorMessage = 'Member profile not found';
          _isLoading = false;
        });
        return;
      }

      final member = Member.fromFirestore(memberDoc);

      // Find member's circle
      final circlesSnapshot = await _firestore
          .collection('stakes')
          .doc(stakeId)
          .collection('wards')
          .doc(wardId)
          .collection('circles')
          .get();

      Circle? myCircle;
      for (var circleDoc in circlesSnapshot.docs) {
        final circle = Circle.fromFirestore(circleDoc);
        if (circle.memberIds.contains(member.id)) {
          myCircle = circle;
          break;
        }
      }

      if (myCircle == null) {
        setState(() {
          _currentMember = member;
          _errorMessage = 'Not assigned to a circle yet';
          _isLoading = false;
        });
        return;
      }

      // Load circle members
      final membersSnapshot = await _firestore
          .collection('stakes')
          .doc(stakeId)
          .collection('wards')
          .doc(wardId)
          .collection('members')
          .get();

      final allMembers = membersSnapshot.docs
          .map((doc) => Member.fromFirestore(doc))
          .toList();

      final circleMembers = allMembers
          .where((m) => myCircle!.memberIds.contains(m.id))
          .toList();

      setState(() {
        _currentMember = member;
        _myCircle = myCircle;
        _circleMembers = circleMembers;
        _isLoading = false;
      });

      // Start listening to real-time updates
      _listenToRealtimeUpdates(stakeId, wardId, myCircle.id);

    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() {
        _errorMessage = 'Error loading dashboard: $e';
        _isLoading = false;
      });
    }
  }

// Add this new method:
  void _listenToRealtimeUpdates(String stakeId, String wardId, String circleId) {
    // Listen to recent chats
    _firestore
        .collection('stakes')
        .doc(stakeId)
        .collection('wards')
        .doc(wardId)
        .collection('circles')
        .doc(circleId)
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _recentChats = snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
      }
    });

    // Listen to upcoming events
    final now = DateTime.now().toIso8601String();
    _firestore
        .collection('stakes')
        .doc(stakeId)
        .collection('wards')
        .doc(wardId)
        .collection('circles')
        .doc(circleId)
        .collection('events')
        .where('eventDate', isGreaterThanOrEqualTo: now)
        .orderBy('eventDate')
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        var upcomingEvents = snapshot.docs
            .map((doc) => CircleEvent.fromFirestore(doc))
            .toList();

        // Add birthday events
        final birthdayEvents = _generateBirthdayEvents(_circleMembers, _currentMember!.id);
        upcomingEvents.addAll(birthdayEvents);
        upcomingEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate));

        setState(() {
          _upcomingEvents = upcomingEvents.take(5).toList();
        });
      }
    });
  }

  List<CircleEvent> _generateBirthdayEvents(List<Member> members, String currentMemberId) {
    final events = <CircleEvent>[];
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    for (var member in members) {
      if (member.dob == null || member.id == currentMemberId) continue;

      try {
        final parts = member.dob!.split('/');
        if (parts.length != 3) continue;

        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);

        // Only show birthdays in the current month
        if (month != currentMonth) continue;

        // Create birthday for this year
        var birthdayThisYear = DateTime(currentYear, month, day);

        // Only add if the birthday hasn't passed yet this month
        if (birthdayThisYear.isAfter(now.subtract(const Duration(days: 1)))) {
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

  Future<void> _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Stake Friends'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initializeDashboard();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Circle'),
            if (_myCircle != null)
              Text(
                _myCircle!.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initializeDashboard();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: RefreshIndicator(
          onRefresh: _initializeDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard Tiles
                _buildDashboardTiles(context, isTablet),

                const SizedBox(height: 24),

                // Recent Chats Section
                _buildRecentChatsSection(context),

                const SizedBox(height: 24),

                // Upcoming Events Section
                _buildUpcomingEventsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTiles(BuildContext context, bool isTablet) {
    return GridView.count(
      crossAxisCount: isTablet ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isTablet ? 1.2 : 1,
      children: [
        _buildDashboardTile(
          context: context,
          title: 'My Circle',
          subtitle: '${_circleMembers.length} members',
          icon: Icons.group,
          color: AppTheme.rosePrimary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CircleMembersScreen(
                  members: _circleMembers,
                  circleName: _myCircle!.name,
                ),
              ),
            );
          },
        ),
        _buildDashboardTile(
          context: context,
          title: 'Chat',
          subtitle: '${_recentChats.length} recent',
          icon: Icons.chat_bubble,
          color: AppTheme.bluePrimary,
          onTap: () {
            if (_myCircle != null && _currentMember != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    circle: _myCircle!,
                    currentMember: _currentMember!,
                    circleMembers: _circleMembers,
                  ),
                ),
              );
            }
          },
        ),
        _buildDashboardTile(
          context: context,
          title: 'Activities',
          subtitle: '${_upcomingEvents.length} upcoming',
          icon: Icons.event,
          color: AppTheme.greenPrimary,
          onTap: () {
            if (_myCircle != null && _currentMember != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActivitiesScreen(
                    circle: _myCircle!,
                    currentMember: _currentMember!,
                    circleMembers: _circleMembers,
                  ),
                ),
              );
            }
          },
        ),
        _buildDashboardTile(
          context: context,
          title: 'My Profile',
          subtitle: 'Edit info',
          icon: Icons.person,
          color: AppTheme.amberPrimary,
          onTap: () {
            if (_currentMember != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    member: _currentMember!,
                  ),
                ),
              ).then((_) => _initializeDashboard());
            }
          },
        ),
      ],
    );
  }

  Widget _buildDashboardTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentChatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Chats',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_recentChats.isNotEmpty)
              TextButton(
                onPressed: () {
                  if (_myCircle != null && _currentMember != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          circle: _myCircle!,
                          currentMember: _currentMember!,
                          circleMembers: _circleMembers,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _recentChats.isEmpty
            ? Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No messages yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentChats.length,
          itemBuilder: (context, index) {
            final chat = _recentChats[index];
            return _buildChatPreview(context, chat);
          },
        ),
      ],
    );
  }

  Widget _buildChatPreview(BuildContext context, ChatMessage chat) {
    String preview = '';
    if (chat.isText) {
      preview = chat.message ?? '';
    } else if (chat.isImage) {
      preview = '📷 Photo';
    } else if (chat.isDocument) {
      preview = '📎 ${chat.fileName ?? 'File'}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.bluePrimary.withOpacity(0.2),
          child: Text(
            chat.memberName.isNotEmpty ? chat.memberName[0] : '?',
            style: const TextStyle(color: AppTheme.bluePrimary),
          ),
        ),
        title: Text(
          chat.memberName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTimestamp(chat.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () {
          if (_myCircle != null && _currentMember != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  circle: _myCircle!,
                  currentMember: _currentMember!,
                  circleMembers: _circleMembers,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildUpcomingEventsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Activities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_upcomingEvents.isNotEmpty)
              TextButton(
                onPressed: () {
                  if (_myCircle != null && _currentMember != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivitiesScreen(
                          circle: _myCircle!,
                          currentMember: _currentMember!,
                          circleMembers: _circleMembers,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _upcomingEvents.isEmpty
            ? Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No upcoming activities',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _upcomingEvents.length,
          itemBuilder: (context, index) {
            final event = _upcomingEvents[index];
            return _buildEventPreview(context, event);
          },
        ),
      ],
    );
  }

  Widget _buildEventPreview(BuildContext context, CircleEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
        subtitle: Text(
          _formatEventDate(event.eventDate),
        ),
        trailing: event.isToday
            ? Chip(
          label: const Text('Today'),
          backgroundColor: AppTheme.amberPrimary.withOpacity(0.3),
        )
            : null,
        onTap: event.isBirthday
            ? null
            : () async {
          // Get user data for the modal
          final authService = Provider.of<AuthService>(context, listen: false);
          final userData = await authService.getUserData();

          if (userData != null && _myCircle != null && _currentMember != null) {
            showDialog(
              context: context,
              builder: (context) => EventDetailModal(
                event: event,
                circle: _myCircle!,
                currentMember: _currentMember!,
                userData: userData,
              ),
            );
          }
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.month}/${timestamp.day}';
  }

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}