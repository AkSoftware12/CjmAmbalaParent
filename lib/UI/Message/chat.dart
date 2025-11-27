import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart'; // Add file_picker package
import '../../constants.dart';

class ChatScreen extends StatefulWidget {
  final int id;
  final int msgSendId;
  final int? messageSendPermissionsApp;
  final String name;
  final String designation;
  const ChatScreen({super.key, required this.id, required this.messageSendPermissionsApp, required this.name, required this.msgSendId, required this.designation});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController messageController = TextEditingController();
  final List<MessageModel> _messages = [];
  bool isLoading = false;
  PlatformFile? selectedFile; // Store the selected file

  // Replace this with the actual user ID/type from logged-in user
  final int currentUserId = 1;
  final String currentUserType = "App\\Models\\Student";

  @override
  void initState() {
    super.initState();
    _fetchMessages(widget.id);
  }

  Future<void> _fetchMessages(int id) async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorSnackBar('No authentication token found');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.getUserMessagesConversation}$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List messagesJson = data['messages'];

        setState(() {
          _messages.clear();
          _messages.addAll(messagesJson.map((json) => MessageModel.fromJson(json)));
          isLoading = false;
        });
      } else {
        // _showErrorSnackBar('Failed to load messages: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // _showErrorSnackBar('Error fetching messages: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to pick a file
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow any file type, or restrict as needed (e.g., FileType.image)
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (messageController.text.trim().isEmpty && selectedFile == null) {
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

    try {
      final uri = Uri.parse(ApiRoutes.sendMessage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields (form data)
      request.fields['receivers[]'] = 'user_${widget.msgSendId}';
      request.fields['body'] = messageController.text.trim();

      // Add file if selected
      if (selectedFile != null && selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            selectedFile!.path!,
            filename: selectedFile!.name,
          ),
        );
      } else {
        request.fields['attachment'] = ''; // No file attached
      }

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchMessages(widget.id);
        messageController.clear();
        setState(() {
          selectedFile = null; // Clear selected file after sending
        });
      } else {
        _showErrorSnackBar('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildMessage(MessageModel message, bool isMe) {
    return Padding(
      padding: isMe ?  EdgeInsets.only(left: 25.sp) :  EdgeInsets.only(right: 25.sp),
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
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(message.attachmentUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      _showErrorSnackBar('Could not open the attachment');
                    }
                  },
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
                ),
              ],
              const SizedBox(height: 4),
              Text(
                message.createdAt.substring(0, 16), // Show only date and time
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
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(
          children: [
             Padding(
              padding: EdgeInsets.only(right: 5.0),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage('https://cdn-icons-png.flaticon.com/512/149/149071.png'),
              ),
            ),
            Expanded(

              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.name}',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp,fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '(${widget.designation})',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.primary,
        elevation: 2,
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final reversedIndex = _messages.length - 1 - index;
                final message = _messages[reversedIndex];
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon:  Icon(Icons.attach_file, color: AppColors.primary),
                        onPressed: _pickFile, // Trigger file picker
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
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
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
      senderType: json['sender_type'] ?? '',
      senderName: json['sender_name'] ?? 'Unknown',
      body: json['body'] ?? '',
      attachmentUrl: json['attachment_url'],
      createdAt: json['created_at'] ?? DateTime.now().toString(),
      seenByReceiver: json['seen_by_receiver'] ?? '',
    );
  }
}