import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../constants.dart';

class AlumniAdminChatScreen extends StatefulWidget {
  final String alumniId;
  final int messageSendPermissionsApp; // ✅ 0 = not allowed, 1 = allowed

  const AlumniAdminChatScreen({
    super.key,
    required this.alumniId,
    this.messageSendPermissionsApp = 1,
  });

  @override
  _AlumniChatScreenState createState() => _AlumniChatScreenState();
}

class _AlumniChatScreenState extends State<AlumniAdminChatScreen>
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

  // ✅ Receiver info comes from the API response ('alumni' object)
  String receiverName = '';
  String receiverPhoto = '';
  String receiverEmail = '';
  String receiverPhone = '';

  // ✅ Logged-in user is the PRINCIPAL/ADMIN side of this chat
  static const String currentSenderType = "principal";

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
    final token = prefs.getString('teachertoken');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      _showErrorSnackBar('No authentication token found');
      return;
    }

    try {
      // ✅ inbox/{alumniId}
      final response = await http.get(
        Uri.parse('${ApiRoutes.getAdminAlumniChat}${widget.alumniId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ Parse alumni (receiver) info — BEFORE any early return
        // so the AppBar fills in even when messages are empty.
        final alumni = data['alumni'];
        if (alumni is Map) {
          final a = alumni.cast<String, dynamic>();
          receiverName = (a['name'] ?? '').toString();
          receiverPhoto = (a['photo'] ?? '').toString();
          receiverEmail = (a['email'] ?? '').toString();
          receiverPhone = (a['phone'] ?? '').toString();
        }

        // ✅ new API: messages are under 'data'
        final List messagesJson = (data['data'] ?? []) as List;

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
        final file = result.files.first;

        // ✅ attachment max:10240 KB = 10 MB
        if (file.size > 10 * 1024 * 1024) {
          _showErrorSnackBar('File must be smaller than 10 MB');
          return;
        }

        if (!mounted) return;
        setState(() {
          selectedFile = file;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  void _showPermissionDeniedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'You do not have permission to send messages. '
              'Please contact the administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetUI() {
    if (!mounted) return;
    setState(() {
      messageController.clear();
      selectedFile = null;
    });
  }

  // ✅ NEW send logic (merged from bulk-send)
  Future<void> _sendMessage() async {
    if (isSending) return;

    final text = messageController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    // message required_without:attachment
    if (text.isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    if (widget.messageSendPermissionsApp == 0) {
      _showPermissionDeniedPopup(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null || token.isEmpty) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    setState(() => isSending = true);

    final fileToSend = selectedFile;

    // ✅ Optimistic UI (chat feel — message turant dikhe)
    final optimistic = MessageModel(
      id: -1,
      senderType: currentSenderType,
      body: text,
      attachmentUrl: fileToSend != null ? "uploading" : null,
      createdAt: DateTime.now().toIso8601String(),
      readAt: null,
    );

    if (mounted) {
      setState(() {
        _messages.insert(0, optimistic);
      });
      _resetUI();
      _scrollToBottom();
    }

    try {
      final uri = Uri.parse(ApiRoutes.sendAdminAlumniMsg);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // ✅ alumni_ids as array — single chat => only this alumni
      request.fields['alumni_ids[0]'] = widget.alumniId.toString();

      // ✅ message
      if (text.isNotEmpty) {
        request.fields['message'] = text;
      }

      debugPrint('📤 alumni_ids → [${widget.alumniId}]');
      debugPrint('📤 message → $text');

      // ✅ attachment (max:10240 KB = 10 MB)
      if (fileToSend != null && fileToSend.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            fileToSend.path!,
            filename: fileToSend.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      debugPrint('📥 Send status → ${response.statusCode}');
      debugPrint('📥 Send body   → ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ chat screen => refresh messages (replaces optimistic bubble)
        await _fetchMessages();
      } else if (response.statusCode == 422) {
        // Validation errors → 'errors' => $validator->errors()->first()
        String msg = 'Validation errors';
        try {
          final data = jsonDecode(response.body);
          msg = data['errors']?.toString() ??
              data['message']?.toString() ??
              msg;
        } catch (_) {}
        _showErrorSnackBar(msg);
        _messages.remove(optimistic);
        await _fetchMessages();
      } else {
        _showErrorSnackBar('Failed: ${response.statusCode}');
        _messages.remove(optimistic);
        await _fetchMessages();
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: $e');
      _messages.remove(optimistic);
      await _fetchMessages();
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
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

    final hour =
    local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
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

  // ✅ Read receipt icon for my messages:
  // ⏱ pending (optimistic, id == -1)
  // ✓✓ grey  => delivered but not read (read_at == null)
  // ✓✓ blue  => read (read_at filled)
  Widget _buildReadStatusIcon(MessageModel message) {
    if (message.id == -1) {
      return const Icon(
        Icons.access_time,
        size: 14,
        color: Colors.black45,
      );
    }

    final isRead =
        message.readAt != null && message.readAt!.trim().isNotEmpty;

    return Icon(
      Icons.done_all,
      size: 16,
      color: isRead ? Colors.blue : Colors.black45,
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
                  // ✅ Read receipts — only on my (principal) messages
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildReadStatusIcon(message),
                  ],
                ],
              ),
              Text(
                isMe
                    ? 'Me'
                    : (receiverName.isNotEmpty ? receiverName : 'Alumni'),
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
        toolbarHeight: 66, // ✅ thoda extra height for 3 lines
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  receiverPhoto.isNotEmpty ? receiverPhoto : _fallbackAvatar,
                ),
                onBackgroundImageError: (_, __) {},
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receiverName.isNotEmpty ? receiverName : 'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (receiverEmail.isNotEmpty)
                    Text(
                      receiverEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (receiverPhone.isNotEmpty)
                    Text(
                      receiverPhone,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                // ✅ sender_type: "principal" => me, "alumni" => them
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
                        onPressed: _sendMessage,
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
  final String senderType; // "alumni" | "principal"
  final String body;
  final String? attachmentUrl;
  final String createdAt;
  final String? readAt;

  MessageModel({
    required this.id,
    required this.senderType,
    required this.body,
    required this.attachmentUrl,
    required this.createdAt,
    required this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      // ✅ 'message' can be null when only attachment is sent
      body: (json['message'] ?? '').toString(),
      attachmentUrl: json['attachment']?.toString(),
      createdAt:
      (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      readAt: json['read_at']?.toString(),
    );
  }
}