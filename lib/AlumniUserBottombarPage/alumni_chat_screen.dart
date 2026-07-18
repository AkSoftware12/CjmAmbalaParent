import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';

class AlumniStudentChatScreen extends StatefulWidget {
  const AlumniStudentChatScreen({super.key});

  @override
  _AlumniChatScreenState createState() => _AlumniChatScreenState();
}

class _AlumniChatScreenState extends State<AlumniStudentChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MessageModel> _messages = [];

  bool isLoading = false; // only first-time loader
  bool isRefreshing = false; // background refresh flag
  bool isSending = false; // prevent multi send
  bool _isFetching = false; // prevent overlapping fetch calls

  PlatformFile? selectedFile;

  Timer? _pollTimer;
  bool _isActive = true; // foreground/background

  // ✅ Receiver info comes from the API response (principal object)
  String receiverName = '';
  String receiverDesignation = '';
  String receiverPhoto = '';

  // ✅ Logged-in user is the alumni; messages sent from app => sender_type "alumni"
  static const String currentSenderType = "alumni";

  static const String _fallbackAvatar =
      'https://cdn-icons-png.flaticon.com/512/149/149071.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fetchMessages(initial: true);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
  }

  void _startAutoFetch() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isActive) return;
      if (_isFetching) return;
      if (isSending) return;

      _isFetching = true;
      try {
        await _fetchMessages();
      } finally {
        _isFetching = false;
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0, // reverse:true => bottom is offset 0
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    if (!mounted) return;

    setState(() {
      if (initial) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');

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
        Uri.parse(ApiRoutes.getAlumniMessage),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ Parse principal (receiver) info — BEFORE any early return
        // so the AppBar fills in even when messages are empty.
        final principal = data['principal'];
        if (principal is Map) {
          final p = principal.cast<String, dynamic>();
          receiverName = (p['name'] ?? '').toString();
          receiverDesignation = (p['designation'] ?? '').toString();
          receiverPhoto = (p['photo'] ?? '').toString();
        }

        final List messagesJson = (data['messages'] ?? []) as List;

        final parsed = messagesJson
            .map((e) =>
            MessageModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList();

        // ✅ backend temporarily empty BUT we already have messages => keep old
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
    final text = messageController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');

    if (token == null) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    final fileToSend = selectedFile;

    // ✅ Optimistic UI
    final optimistic = MessageModel(
      id: -1,
      alumniId: -1,
      senderType: currentSenderType,
      body: text,
      attachmentUrl: fileToSend != null ? "uploading" : null,
      createdAt: DateTime.now().toIso8601String(),
      readAt: null,
    );

    if (mounted) {
      setState(() {
        _messages.insert(0, optimistic);
        messageController.clear();
        selectedFile = null;
      });
      _scrollToBottom();
    }

    try {
      final uri = Uri.parse(ApiRoutes.alumniMessageSend);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // ✅ New API: only 'message' field needed, sender_type is set by backend
      request.fields['message'] = text;

      if (fileToSend != null && fileToSend.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            fileToSend.path!,
            filename: fileToSend.name,
          ),
        );
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchMessages();
      } else {
        _showErrorSnackBar('Failed to send message: ${response.statusCode}');
        await _fetchMessages();
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
      await _fetchMessages();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48.sp, color: Colors.grey.shade400),
          SizedBox(height: 12.sp),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4.sp),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String createdAt) {
    final dt = DateTime.tryParse(createdAt);

    if (dt == null) {
      return createdAt;
    }

    final local = dt.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';

    return '${two(local.day)}-${two(local.month)}-${local.year} '
        '${two(hour)}:${two(local.minute)} $amPm';
  }

  // ✅ check if attachment is an image
  bool _isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  // ✅ full screen image viewer
  void _openImageFullScreen(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 60,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ image bubble widget
  Widget _buildImageAttachment(String url) {
    return GestureDetector(
      onTap: () => _openImageFullScreen(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 200.sp,
            maxHeight: 250.sp,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200.sp,
                height: 150.sp,
                color: Colors.grey.shade300,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              width: 200.sp,
              height: 100.sp,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ non-image attachment => button (pdf, doc, etc.)
  Widget _buildFileAttachment(String url, bool isMe) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _buildMessage(MessageModel message, bool isMe) {
    final isUploading = message.attachmentUrl == "uploading";
    final hasText = message.body.trim().isNotEmpty;
    final attachmentUrl = message.attachmentUrl;
    final hasAttachment = !isUploading &&
        attachmentUrl != null &&
        attachmentUrl.trim().isNotEmpty;

    return Padding(
      padding:
      isMe ? EdgeInsets.only(left: 25.sp) : EdgeInsets.only(right: 25.sp),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isMe ? Colors.grey.shade200 : Colors.grey.shade300,
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
              const SizedBox(height: 4),

              if (isUploading) ...[
                if (hasText) const SizedBox(height: 6),
                const Text(
                  "Uploading...",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // ✅ Attachment: image => show image, else => button
              if (hasAttachment) ...[
                if (hasText) const SizedBox(height: 8),
                _isImageUrl(attachmentUrl)
                    ? _buildImageAttachment(attachmentUrl.trim())
                    : _buildFileAttachment(attachmentUrl.trim(), isMe),
              ],

              const SizedBox(height: 4),
              // ✅ Text only when message exists
              if (hasText)
                SelectableLinkify(
                  text: message.body,
                  onOpen: _onOpen,
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.45,
                    color: isMe ? Colors.black : Colors.black87,
                  ),
                  linkStyle: TextStyle(
                    color: Colors.blue,
                    fontSize: 14.sp,
                    height: 1.45,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              const SizedBox(height: 4),

              // ✅ time + read status (ticks)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    message.id == -1
                    // ✅ optimistic (sending...) => clock
                        ? const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.black45,
                    )
                        : Icon(
                      Icons.done_all,
                      size: 16,
                      color: message.readAt != null
                          ? Colors.blue // ✅ read
                          : Colors.black38, // ✅ delivered, not read
                    ),
                  ],
                ],
              ),

              Text(
                isMe
                    ? 'Me'
                    : (receiverName.isNotEmpty ? receiverName : 'Principal'),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: isMe ? AppColors.primary : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOpen(LinkableElement link) async {
    if (!await launchUrl(Uri.parse(link.url))) {
      throw Exception('Could not launch ${link.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  receiverPhoto.isNotEmpty ? receiverPhoto : _fallbackAvatar,
                ),
                onBackgroundImageError: (_, __) {},
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receiverName.isNotEmpty ? receiverName : 'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (receiverDesignation.isNotEmpty)
                    Text(
                      '($receiverDesignation)',
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
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // ✅ new API: sender_type is "alumni" or "principal"
                final isMe =
                    message.senderType == currentSenderType;
                return _buildMessage(message, isMe);
              },
            ),
          ),
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
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                TextCapitalization.sentences,
                                style: TextStyle(
                                    fontSize: 14.sp, color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14.sp),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 6),
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
                            valueColor:
                            AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.send,
                            color: Colors.white),
                        onPressed: handleSend,
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
  final int id;
  final int alumniId;
  final String senderType; // "alumni" | "principal"
  final String body;
  final String? attachmentUrl;
  final String createdAt;
  final String? readAt;

  MessageModel({
    required this.id,
    required this.alumniId,
    required this.senderType,
    required this.body,
    required this.attachmentUrl,
    required this.createdAt,
    required this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      alumniId: json['alumni_id'] is int
          ? json['alumni_id'] as int
          : int.tryParse('${json['alumni_id']}') ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      // ✅ new API uses 'message' instead of 'body'
      body: (json['message'] ?? '').toString(),
      // ✅ API key 'attachment' hai
      attachmentUrl: json['attachment']?.toString(),
      createdAt:
      (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      readAt: json['read_at']?.toString(),
    );
  }
}