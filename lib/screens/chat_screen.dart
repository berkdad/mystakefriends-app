import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/circle_modal.dart';
import '../models/event_modal.dart';
import '../models/member_modal.dart';
import '../services/auth_service.dart';

import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  final Circle circle;
  final Member currentMember;
  final List<Member> circleMembers;

  const ChatScreen({
    super.key,
    required this.circle,
    required this.currentMember,
    required this.circleMembers,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isNotificationsEnabled = true;
  bool _isSending = false;
  String? _userData;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    _setInChatStatus(true);
    _loadUserData();
  }

  @override
  void dispose() {
    _setInChatStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userData = await authService.getUserData();
    setState(() {
      _userData = userData?['stakeId'];
    });
  }

  Future<void> _setInChatStatus(bool isInChat) async {
    final fcmService = Provider.of<FCMService>(context, listen: false);
    await fcmService.setChatScreenStatus(isInChat);
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationsEnabled = prefs.getBool('chat_notifications_${widget.circle.id}') ?? true;
    });
  }

  Future<void> _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_isNotificationsEnabled;
    await prefs.setBool('chat_notifications_${widget.circle.id}', newValue);

    setState(() {
      _isNotificationsEnabled = newValue;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? 'Chat notifications enabled'
              : 'Chat notifications disabled',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData();

      await _firestore
          .collection('stakes')
          .doc(userData!['stakeId'])
          .collection('wards')
          .doc(userData['wardId'])
          .collection('circles')
          .doc(widget.circle.id)
          .collection('chats')
          .add({
        'memberId': widget.currentMember.id,
        'memberName': widget.currentMember.displayName,
        'type': 'text',
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      await _uploadFile(File(image.path), 'image', image.name);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      await _uploadFile(file, 'document', result.files.single.name);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _uploadFile(File file, String type, String fileName) async {
    setState(() => _isSending = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData();

      // Upload to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child(
        'circles/${widget.circle.id}/chat/${timestamp}_$fileName',
      );

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create chat message
      await _firestore
          .collection('stakes')
          .doc(userData!['stakeId'])
          .collection('wards')
          .doc(userData['wardId'])
          .collection('circles')
          .doc(widget.circle.id)
          .collection('chats')
          .add({
        'memberId': widget.currentMember.id,
        'memberName': widget.currentMember.displayName,
        'type': type,
        'fileUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': await file.length(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Circle Chat'),
            Text(
              widget.circle.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isNotificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            onPressed: _toggleNotifications,
            tooltip: _isNotificationsEnabled
                ? 'Disable notifications'
                : 'Enable notifications',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: authService.getUserData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.data!;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('stakes')
                      .doc(userData['stakeId'])
                      .collection('wards')
                      .doc(userData['wardId'])
                      .collection('circles')
                      .doc(widget.circle.id)
                      .collection('chats')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs
                        .map((doc) => ChatMessage.fromFirestore(doc))
                        .toList();

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isCurrentUser = message.memberId == widget.currentMember.id;
                        final member = widget.circleMembers.firstWhere(
                              (m) => m.id == message.memberId,
                          orElse: () => widget.currentMember,
                        );

                        return _buildMessageBubble(message, isCurrentUser, member);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _isSending ? null : _pickAndUploadFile,
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _isSending ? null : _pickAndUploadImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                    color: AppTheme.bluePrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isCurrentUser, Member member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.bluePrimary.withOpacity(0.2),
              backgroundImage: member.profilePicUrl != null
                  ? NetworkImage(member.profilePicUrl!)
                  : null,
              child: member.profilePicUrl == null
                  ? Text(
                member.fullName.isNotEmpty ? member.fullName[0] : '?',
                style: const TextStyle(fontSize: 14),
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.memberName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? AppTheme.bluePrimary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildMessageContent(message, isCurrentUser),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isCurrentUser) {
    if (message.isText) {
      return Text(
        message.message!,
        style: TextStyle(
          color: isCurrentUser ? Colors.white : Colors.black87,
        ),
      );
    } else if (message.isImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: message.fileUrl!,
              width: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade300,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          if (message.fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message.fileName!,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrentUser ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
        ],
      );
    } else if (message.isDocument) {
      return InkWell(
        onTap: () async {
          final uri = Uri.parse(message.fileUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isCurrentUser ? Colors.white : AppTheme.bluePrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Document',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (message.fileSize != null)
                    Text(
                      '${(message.fileSize! / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              size: 20,
              color: isCurrentUser ? Colors.white : AppTheme.bluePrimary,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}