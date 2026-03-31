import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class MessageModel {
  final int senderId;
  final String senderType;
  final String senderName;
  final String body;
  final String? attachmentUrl;
  final String createdAt;
  final String? seenByReceiver;
  final int send; // ✅ 1 = mera message, 0 = received

  const MessageModel({
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachmentUrl,
    required this.createdAt,
    required this.seenByReceiver,
    required this.send,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      senderId: json['sender_id'] ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      senderName: (json['sender_name'] ?? 'Unknown').toString(),
      body: (json['body'] ?? '').toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      seenByReceiver: json['seen_by_receiver']?.toString(),
      send: json['send'] ?? 0, // ✅
    );
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class TeacherChatScreen extends StatefulWidget {
  final int id;
  final String msgSendId;
  final int? messageSendPermissionsApp;
  final String name;
  final String designation;

  const TeacherChatScreen({
    super.key,
    required this.id,
    required this.messageSendPermissionsApp,
    required this.name,
    required this.msgSendId,
    required this.designation,
  });

  @override
  State<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends State<TeacherChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  PlatformFile? _selectedFile;

  Timer? _pollTimer;
  bool _isDisposed = false;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Polling ──────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _isDisposed || _isSending) return;
      _fetchMessages();
    });
  }

  // ── Fetch ────────────────────────────────────

  Future<void> _fetchMessages({bool initial = false}) async {
    if (!mounted || _isDisposed || _inFlight) return;
    _inFlight = true;
    try {
      if (initial && mounted) setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiRoutes.getTeacherMessagesConversation}${widget.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted || _isDisposed) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List raw = data['messages'] ?? [];

        // API oldest-first deta hai → reverse for ListView (reverse: true)
        final fetched = raw
            .map((j) => MessageModel.fromJson(j as Map<String, dynamic>))
            .toList()
            .reversed
            .toList();

        if (!_isSending && mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(fetched);
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    } finally {
      _inFlight = false;
      if (initial && mounted) setState(() => _isLoading = false);
    }
  }

  // ── Send ─────────────────────────────────────

  // Future<void> _handleSend() async {
  //   if (_isSending) return;
  //   final text = _messageController.text.trim();
  //   if (text.isEmpty && _selectedFile == null) return;
  //   if ((widget.messageSendPermissionsApp ?? 1) == 0) {
  //     _showSnackBar('Permission denied', isError: true);
  //     return;
  //   }
  //
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('teachertoken');
  //   if (token == null) return;
  //
  //   final fileToSend = _selectedFile;
  //
  //   // Optimistic — send: 1 (mera message)
  //   final optimistic = MessageModel(
  //     senderId: 0,
  //     senderType: "App\\Models\\User",
  //     senderName: "Me",
  //     body: text,
  //     attachmentUrl: fileToSend != null ? "uploading" : null,
  //     createdAt: DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
  //     seenByReceiver: null,
  //     send: 1, // ✅ mera message
  //   );
  //
  //   setState(() {
  //     _isSending = true;
  //     _messages.insert(0, optimistic);
  //     _messageController.clear();
  //     _selectedFile = null;
  //   });
  //   _scrollToBottom();
  //
  //   try {
  //     final uri = Uri.parse(ApiRoutes.sendTeacherMessage);
  //     final request = http.MultipartRequest('POST', uri)
  //       ..headers['Authorization'] = 'Bearer $token'
  //       ..fields['receivers[]'] = widget.msgSendId
  //       ..fields['body'] = text;
  //
  //     if (fileToSend?.path != null) {
  //       request.files.add(await http.MultipartFile.fromPath(
  //         'attachment',
  //         fileToSend!.path!,
  //         filename: fileToSend.name,
  //       ));
  //     } else {
  //       request.fields['attachment'] = '';
  //     }
  //
  //     final response = await request.send();
  //     final responseBody = await response.stream.bytesToString();
  //     debugPrint('Send [${response.statusCode}]: $responseBody');
  //
  //     if (!mounted || _isDisposed) return;
  //     await _fetchMessages();
  //   } catch (e) {
  //     debugPrint('Send error: $e');
  //     if (mounted) _showSnackBar('Error: $e', isError: true);
  //     await _fetchMessages();
  //   } finally {
  //     if (mounted) setState(() => _isSending = false);
  //   }
  // }

  // ── File Picker ──────────────────────────────


  Future<void> _handleSend() async {
    if (_isSending) return;

    final text = _messageController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty && _selectedFile == null) return;

    if ((widget.messageSendPermissionsApp ?? 1) == 0) {
      _showSnackBar('Permission denied', isError: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    if (token == null) return;

    final fileToSend = _selectedFile;

    final optimistic = MessageModel(
      senderId: 0,
      senderType: "App\\Models\\User",
      senderName: "Me",
      body: text,
      attachmentUrl: fileToSend != null ? "uploading" : null,
      createdAt: DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
      seenByReceiver: null,
      send: 1,
    );

    setState(() {
      _isSending = true;
      _messages.insert(0, optimistic);
      _messageController.clear();
      _selectedFile = null;
    });

    _scrollToBottom();

    try {
      final uri = Uri.parse(ApiRoutes.sendTeacherMessage);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['receivers[]'] = widget.msgSendId
        ..fields['body'] = text; // yaha multiline text jayega

      if (fileToSend?.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'attachment',
          fileToSend!.path!,
          filename: fileToSend.name,
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint(responseBody);
      await _fetchMessages();
    } catch (e) {
      debugPrint('Send error: $e');
      _showSnackBar('Error sending message', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: false);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  // ── Helpers ──────────────────────────────────

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ✅ FINAL FIX: send == 1 → mera message (right), send == 0 → received (left)
  bool _isMe(MessageModel msg) => msg.send == 1;

  // Parse "dd-MM-yyyy HH:mm" format
  DateTime? _parseDate(String raw) {
    try {
      return DateFormat('dd-MM-yyyy HH:mm').parse(raw);
    } catch (_) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatTime(String raw) {
    final dt = _parseDate(raw);
    if (dt == null) return raw;
    return DateFormat('hh:mm a').format(dt);
  }

  String _formatDate(String raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_selectedFile != null) _buildFilePreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white24,
            child: Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(widget.designation,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Message List ─────────────────────────────

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text('No messages yet. Say hello! 👋',
                style:
                TextStyle(color: Colors.grey.shade500, fontSize: 13.sp)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = _isMe(msg);

        final showDate = index == _messages.length - 1 ||
            _formatDate(msg.createdAt) !=
                _formatDate(_messages[index + 1].createdAt);

        final showAvatar =
            index == 0 || _isMe(_messages[index - 1]) != isMe;

        return Column(
          children: [
            if (showDate) _buildDateSeparator(msg.createdAt),
            _buildRow(msg, isMe, showAvatar),
          ],
        );
      },
    );
  }

  // ── Date Separator ───────────────────────────

  Widget _buildDateSeparator(String raw) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: Colors.grey.shade400, thickness: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_formatDate(raw),
                style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Divider(color: Colors.grey.shade400, thickness: 0.5)),
        ],
      ),
    );
  }

  // ── Message Row (avatar + bubble) ────────────

  Widget _buildRow(MessageModel msg, bool isMe, bool showAvatar) {
    final avatarWidget =
    showAvatar ? _buildAvatar(msg, isMe) : SizedBox(width: 36.w);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? [
          _buildBubble(msg, isMe),
          const SizedBox(width: 6),
          avatarWidget,
        ]
            : [
          avatarWidget,
          const SizedBox(width: 6),
          _buildBubble(msg, isMe),
        ],
      ),
    );
  }

  // ── Avatar ───────────────────────────────────

  Widget _buildAvatar(MessageModel msg, bool isMe) {
    final initial =
    msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?';
    final color = isMe ? AppColors.primary : const Color(0xFF607D8B);
    return CircleAvatar(
      radius: 17,
      backgroundColor: color.withOpacity(0.15),
      child: Text(initial,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp)),
    );
  }

  // ── Bubble ───────────────────────────────────

  Widget _buildBubble(MessageModel msg, bool isMe) {
    final isUploading = msg.attachmentUrl == "uploading";
    final hasAttachment = !isUploading &&
        msg.attachmentUrl != null &&
        msg.attachmentUrl!.isNotEmpty;

    final bubbleColor = isMe ? Colors.grey.shade200 : Colors.white;
    final textColor = isMe ? Colors.black : const Color(0xFF1C1C1E);
    final timeColor = isMe ? Colors.black : Colors.grey.shade500;
    final isSeen =
        msg.seenByReceiver != null && msg.seenByReceiver!.isNotEmpty;

    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name — sirf received pe
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(msg.senderName,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                ),

              // Body text
              if (msg.body.isNotEmpty)
                Text(msg.body,
                    style: TextStyle(
                        color: textColor, fontSize: 14.sp, height: 1.45)),

              // Uploading spinner
              if (isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 11,
                        width: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              isMe ? Colors.white70 : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('Uploading...',
                          style:
                          TextStyle(color: timeColor, fontSize: 11.sp)),
                    ],
                  ),
                ),

              // Attachment
              if (hasAttachment) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(msg.attachmentUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } else {
                      _showSnackBar('Could not open attachment',
                          isError: true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.18)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMe
                            ? Colors.white30
                            : AppColors.primary.withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file_rounded,
                            size: 15,
                            color: isMe ? Colors.white : AppColors.primary),
                        const SizedBox(width: 5),
                        Text('Open Attachment',
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : AppColors.primary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],

              // Time + tick
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(msg.createdAt),
                      style:
                      TextStyle(color: timeColor, fontSize: 10.sp)),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    Icon(
                      isSeen
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: isSeen
                          ? Colors.lightBlueAccent
                          : Colors.white54,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── File Preview ─────────────────────────────

  Widget _buildFilePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_selectedFile!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedFile = null),
            child: Icon(Icons.close_rounded,
                color: Colors.grey.shade600, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: _isSending ? null : _pickFile,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.attach_file_rounded,
                    color: _isSending
                        ? Colors.grey.shade400
                        : AppColors.primary,
                    size: 22),
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !_isSending,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style:
                    TextStyle(fontSize: 14.sp, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14.sp),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _handleSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isSending
                      ? Colors.grey.shade400
                      : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: _isSending
                      ? []
                      : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}