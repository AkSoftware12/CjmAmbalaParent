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

enum MessageStatus { sending, sent, failed }

class MessageModel {
  final int? id; // server id
  final String localId; // local temp id
  final int senderId;
  final String senderType;
  final String senderName;
  final String body;
  final String? attachmentUrl;
  final String createdAt;
  final String? seenByReceiver;
  final int send; // 1 = mine, 0 = received
  final MessageStatus status;

  const MessageModel({
    this.id,
    required this.localId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachmentUrl,
    required this.createdAt,
    required this.seenByReceiver,
    required this.send,
    required this.status,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      localId: 'server_${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      senderId: json['sender_id'] ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      senderName: (json['sender_name'] ?? 'Unknown').toString(),
      body: (json['body'] ?? '').toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      seenByReceiver: json['seen_by_receiver']?.toString(),
      send: json['send'] ?? 0,
      status: MessageStatus.sent,
    );
  }

  MessageModel copyWith({
    int? id,
    String? localId,
    int? senderId,
    String? senderType,
    String? senderName,
    String? body,
    String? attachmentUrl,
    String? createdAt,
    String? seenByReceiver,
    int? send,
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      createdAt: createdAt ?? this.createdAt,
      seenByReceiver: seenByReceiver ?? this.seenByReceiver,
      send: send ?? this.send,
      status: status ?? this.status,
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
  bool _isDisposed = false;
  bool _inFlight = false;

  PlatformFile? _selectedFile;
  Timer? _pollTimer;

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

  // ─────────────────────────────────────────────
  // POLLING
  // ─────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _isDisposed) return;
      _fetchMessages();
    });
  }

  // ─────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────

  Future<void> _fetchMessages({bool initial = false}) async {
    if (!mounted || _isDisposed || _inFlight) return;

    _inFlight = true;

    try {
      if (initial && mounted) {
        setState(() => _isLoading = true);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiRoutes.getTeacherMessagesConversation}${widget.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted || _isDisposed) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List raw = data['messages'] ?? [];

        final serverMessages = raw
            .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
            .toList()
            .reversed
            .toList();

        // local pending messages preserve rakhna
        final pendingLocal = _messages
            .where((m) =>
        m.status == MessageStatus.sending ||
            m.status == MessageStatus.failed)
            .toList();

        final merged = <MessageModel>[
          ...pendingLocal,
          ...serverMessages,
        ];

        // duplicate remove by id/localId
        final unique = <MessageModel>[];
        final seenIds = <String>{};

        for (final msg in merged) {
          final key = msg.id != null ? 'id_${msg.id}' : 'local_${msg.localId}';
          if (seenIds.add(key)) {
            unique.add(msg);
          }
        }

        if (mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(unique);
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    } finally {
      _inFlight = false;
      if (initial && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // SEND
  // ─────────────────────────────────────────────

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

    if (token == null) {
      _showSnackBar('Token not found', isError: true);
      return;
    }

    final fileToSend = _selectedFile;
    final localId = DateTime.now().microsecondsSinceEpoch.toString();

    final optimistic = MessageModel(
      id: null,
      localId: localId,
      senderId: 0,
      senderType: "App\\Models\\User",
      senderName: "Me",
      body: text,
      attachmentUrl: fileToSend != null ? "uploading" : null,
      createdAt: DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
      seenByReceiver: null,
      send: 1,
      status: MessageStatus.sending,
    );

    setState(() {
      _isSending = true;
      _messages.insert(0, optimistic);
      _messageController.clear();
      _selectedFile = null;
    });

    _scrollToBottom();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiRoutes.sendTeacherMessage),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..fields['receivers[]'] = widget.msgSendId
        ..fields['body'] = text;

      if (fileToSend?.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            fileToSend!.path!,
            filename: fileToSend.name,
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint('SEND [${response.statusCode}] => $responseBody');

      if (!mounted || _isDisposed) return;

      if (response.statusCode == 200 || response.statusCode == 201|| response.statusCode == 202) {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(responseBody);
        } catch (_) {}

        final dynamic messageJson =
            decoded?['message'] ?? decoded?['data'] ?? decoded;

        if (messageJson is Map<String, dynamic>) {
          final sentMessage = MessageModel(
            id: messageJson['id'],
            localId: localId,
            senderId: messageJson['sender_id'] ?? 0,
            senderType:
            (messageJson['sender_type'] ?? "App\\Models\\User").toString(),
            senderName: (messageJson['sender_name'] ?? "Me").toString(),
            body: (messageJson['body'] ?? text).toString(),
            attachmentUrl: messageJson['attachment_url']?.toString(),
            createdAt: (messageJson['created_at'] ??
                DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()))
                .toString(),
            seenByReceiver: messageJson['seen_by_receiver']?.toString(),
            send: 1,
            status: MessageStatus.sent,
          );

          final index = _messages.indexWhere((m) => m.localId == localId);
          if (index != -1) {
            setState(() {
              _messages[index] = sentMessage;
            });
          }
        } else {
          final index = _messages.indexWhere((m) => m.localId == localId);
          if (index != -1) {
            setState(() {
              _messages[index] =
                  _messages[index].copyWith(status: MessageStatus.sent);
            });
          }
        }

        await _fetchMessages();
      } else {
        final index = _messages.indexWhere((m) => m.localId == localId);
        if (index != -1) {
          setState(() {
            _messages[index] =
                _messages[index].copyWith(status: MessageStatus.failed);
          });
        }
        _showSnackBar('Message send failed', isError: true);
      }
    } catch (e) {
      debugPrint('Send error: $e');

      final index = _messages.indexWhere((m) => m.localId == localId);
      if (index != -1) {
        setState(() {
          _messages[index] =
              _messages[index].copyWith(status: MessageStatus.failed);
        });
      }

      _showSnackBar('Error sending message', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────

  Future<void> _deleteMessage(MessageModel msg) async {
    // local pending / failed delete
    if (msg.status == MessageStatus.sending ||
        msg.status == MessageStatus.failed ||
        msg.id == null) {
      setState(() {
        _messages.removeWhere((m) => m.localId == msg.localId);
      });
      _showSnackBar('Message removed');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      if (token == null) {
        _showSnackBar('Token not found', isError: true);
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiRoutes.messageDelete}${msg.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('DELETE [${response.statusCode}] => ${response.body}');

      if (!mounted || _isDisposed) return;

      if (response.statusCode == 200) {
        setState(() {
          _messages.removeWhere((m) => m.id == msg.id);
        });
        _showSnackBar('Message deleted successfully');
        await _fetchMessages();
      } else {
        _showSnackBar('Failed to delete message', isError: true);
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      _showSnackBar('Delete error: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────
  // PICK FILE
  // ─────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  bool _isMe(MessageModel msg) => msg.send == 1;

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
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _showDeleteSheet(MessageModel msg) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // icon
                  Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // title
                  const Text(
                    'Delete message?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // subtitle
                  Text(
                    msg.status == MessageStatus.sending
                        ? 'This message is still sending. It will be removed from your chat.'
                        : 'This message will be deleted from the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, 'delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == 'delete') {
      await _deleteMessage(msg);
    }
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

  // ─────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
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
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.designation,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MESSAGE LIST
  // ─────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'No messages yet. Say hello! 👋',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13.sp,
              ),
            ),
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

  Widget _buildDateSeparator(String raw) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey.shade400, thickness: 0.5),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDate(raw),
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: Colors.grey.shade400, thickness: 0.5),
          ),
        ],
      ),
    );
  }

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

  Widget _buildAvatar(MessageModel msg, bool isMe) {
    final initial =
    msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?';
    final color = isMe ? AppColors.primary : const Color(0xFF607D8B);

    return CircleAvatar(
      radius: 17,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMe) {
    final isUploading = msg.status == MessageStatus.sending;
    final hasAttachment = !isUploading &&
        msg.attachmentUrl != null &&
        msg.attachmentUrl!.isNotEmpty;

    final bubbleColor = isMe ? Colors.grey.shade200 : Colors.white;
    final textColor = isMe ? Colors.black : const Color(0xFF1C1C1E);
    final timeColor = Colors.grey.shade500;
    final isSeen =
        msg.seenByReceiver != null && msg.seenByReceiver!.isNotEmpty;

    return GestureDetector(
      onLongPress: isMe ? () => _showDeleteSheet(msg) : null,
      child: Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
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
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                if (msg.body.isNotEmpty)
                  Text(
                    msg.body,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.sp,
                      height: 1.45,
                    ),
                  ),

                if (isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 11,
                          width: 11,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Sending...',
                          style: TextStyle(
                            color: timeColor,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (msg.status == MessageStatus.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Failed to send',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (hasAttachment) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(msg.attachmentUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        _showSnackBar(
                          'Could not open attachment',
                          isError: true,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Open Attachment',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 10.sp,
                      ),
                    ),
                    if (isMe && msg.status == MessageStatus.sent) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isSeen
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 13,
                        color: isSeen ? Colors.lightBlueAccent : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FILE PREVIEW
  // ─────────────────────────────────────────────

  Widget _buildFilePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedFile!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedFile = null),
            child: Icon(
              Icons.close_rounded,
              color: Colors.grey.shade600,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────────

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
                child: Icon(
                  Icons.attach_file_rounded,
                  color: _isSending
                      ? Colors.grey.shade400
                      : AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14.sp,
                      ),
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
                  color:
                  _isSending ? Colors.grey.shade400 : AppColors.primary,
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
                      : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}