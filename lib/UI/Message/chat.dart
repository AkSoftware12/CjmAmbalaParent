import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';

class ChatScreen extends StatefulWidget {
  final int id;
  final int msgSendId;
  final int? messageSendPermissionsApp;
  final String name;
  final String designation;

  const ChatScreen({
    super.key,
    required this.id,
    required this.messageSendPermissionsApp,
    required this.name,
    required this.msgSendId,
    required this.designation,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MessageModel> _messages = [];

  bool isLoading = false;      // only first-time loader
  bool isRefreshing = false;   // background refresh flag
  bool isSending = false;      // prevent multi send
  bool _isFetching = false;    // prevent overlapping fetch calls

  PlatformFile? selectedFile;

  Timer? _pollTimer;
  bool _isActive = true; // foreground/background

  // Replace this with actual logged-in user
  final int currentUserId = 1;
  final String currentUserType = "App\\Models\\Student";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fetchMessages(widget.id, initial: true);
    _startAutoFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _pollTimer?.cancel();
    _pollTimer = null;

    _scrollController.dispose();
    messageController.dispose();

    super.dispose();
  }

  // ✅ Foreground/background detect
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
  }

  void _startAutoFetch() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isActive) return;      // background me hit mat karo
      if (_isFetching) return;     // overlapping avoid
      if (isSending) return;       // ✅ sending ke time refresh mat karo (optimistic wipe avoid)

      _isFetching = true;
      try {
        await _fetchMessages(widget.id);
      } finally {
        _isFetching = false;
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0, // ✅ reverse:true => bottom is offset 0
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ✅ fetch with: initial loader + safe empty guard + newest-first
  Future<void> _fetchMessages(int id, {bool initial = false}) async {
    if (!mounted) return;

    setState(() {
      if (initial) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      _showErrorSnackBar('No authentication token found');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.getUserMessagesConversation}$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List messagesJson = (data['messages'] ?? []) as List;

        final parsed = messagesJson
            .map((e) => MessageModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList();

        // ✅ backend temporary empty => keep old messages
        if (parsed.isEmpty && _messages.isNotEmpty) {
          setState(() {
            isLoading = false;
            isRefreshing = false;
          });
          return;
        }

        // ✅ keep newest-first (best with reverse:true)
        final newestFirst = parsed.reversed.toList();

        // ✅ if sending, don't wipe optimistic
        if (isSending) {
          setState(() {
            isLoading = false;
            isRefreshing = false;
          });
          return;
        }

        setState(() {
          _messages
            ..clear()
            ..addAll(newestFirst);

          isLoading = false;
          isRefreshing = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  // ✅ Pick a file
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  // ✅ send wrapper (prevent double click)
  Future<void> handleSend() async {
    if (isSending) return;
    setState(() => isSending = true);

    await _sendMessage();

    if (mounted) {
      setState(() => isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    if (currentUserType != "App\\Models\\Student") {
      _showErrorSnackBar('Only students can send messages');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    final fileToSend = selectedFile;

    // ✅ Optimistic UI (instant show)
    final optimistic = MessageModel(
      senderId: currentUserId,
      senderType: currentUserType,
      senderName: "Me",
      body: text,
      attachmentUrl: fileToSend != null ? "uploading" : null, // marker
      createdAt: DateTime.now().toIso8601String(),
      seenByReceiver: "0",
    );

    if (mounted) {
      setState(() {
        // ✅ reverse:true => newest at index 0
        _messages.insert(0, optimistic);
        messageController.clear();
        selectedFile = null;
      });
      _scrollToBottom();
    }

    try {
      final uri = Uri.parse(ApiRoutes.sendMessage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['receivers[]'] = 'user_${widget.msgSendId}';
      request.fields['body'] = text;

      if (fileToSend != null && fileToSend.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            fileToSend.path!,
            filename: fileToSend.name,
          ),
        );
      } else {
        request.fields['attachment'] = '';
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ after success, fetch latest from server (replace optimistic)
        await _fetchMessages(widget.id);
      } else {
        _showErrorSnackBar('Failed to send message: ${response.statusCode}');
        await _fetchMessages(widget.id);
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
      await _fetchMessages(widget.id);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildMessage(MessageModel message, bool isMe) {
    final isUploading = message.attachmentUrl == "uploading";

    return Padding(
      padding: isMe
          ? EdgeInsets.only(left: 25.sp)
          : EdgeInsets.only(right: 25.sp),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 0 : 12),
              bottomRight: Radius.circular(isMe ? 12 : 0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              if (isUploading) ...[
                const SizedBox(height: 6),
                Text(
                  "Uploading...",
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!isUploading &&
                  message.attachmentUrl != null &&
                  message.attachmentUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(message.attachmentUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } else {
                      _showErrorSnackBar('Could not open the attachment');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.grey[200] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attachment,
                          size: 16,
                          color: isMe ? Colors.black : Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Attachment',
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.blueAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                message.createdAt.length >= 16
                    ? message.createdAt.substring(0, 16)
                    : message.createdAt,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 5.0),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '(${widget.designation})',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.primary,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: (isLoading && _messages.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index]; // ✅ fixed (no double reverse)
                final isMe = message.senderType == currentUserType;
                return _buildMessage(message, isMe);
              },
            ),
          ),
          if (widget.messageSendPermissionsApp == 1)
            SafeArea(
              child: Card(
                color: Colors.grey.shade200,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.attach_file, color: AppColors.primary),
                        onPressed: isSending ? null : _pickFile,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: messageController,
                                  enabled: !isSending,
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (selectedFile != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    selectedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: isSending
                            ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.white),
                            ),
                          ),
                        )
                            : IconButton(
                          icon: const Icon(Icons.send,
                              color: Colors.white),
                          onPressed: _sendMessage, // ✅ fixed
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MessageModel {
  final int senderId;
  final String senderType;
  final String senderName;
  final String body;
  final String? attachmentUrl;
  final String createdAt;
  final String seenByReceiver;

  MessageModel({
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachmentUrl,
    required this.createdAt,
    required this.seenByReceiver,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      senderId: json['sender_id'] ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      senderName: (json['sender_name'] ?? 'Unknown').toString(),
      body: (json['body'] ?? '').toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      createdAt:
      (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      seenByReceiver: (json['seen_by_receiver'] ?? '').toString(),
    );
  }
}