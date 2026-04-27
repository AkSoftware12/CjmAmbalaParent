import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonCalling/data_not_found.dart';
import '../../../../CommonCalling/progressbarWhite.dart';
import '../../../../constants.dart';
import 'message_detail_screen.dart';

class SendMsgScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const SendMsgScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<SendMsgScreen> createState() => _SendMsgScreenState();
}

class _SendMsgScreenState extends State<SendMsgScreen> {
  bool isLoading = false;

  List messages = [];
  List filteredMessages = [];

  final TextEditingController searchController = TextEditingController();

  int currentPage = 1;
  int totalPages = 1;
  int totalChat = 0;

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null || token.isEmpty) {
      setState(() {
        isLoading = false;
        messages = [];
        filteredMessages = [];
      });
      return;
    }

    try {
      final Uri url = Uri.parse(
        '${ApiRoutes.getMessageSendList}?page=$currentPage',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        messages = jsonResponse['data'] ?? [];
        totalPages = jsonResponse['pagination']?['last_page'] ?? 1;
        totalChat = jsonResponse['pagination']?['total'] ?? messages.length;

        filterMessages(searchController.text);
      } else {
        messages = [];
        filteredMessages = [];
      }
    } catch (e) {
      messages = [];
      filteredMessages = [];
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterMessages(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredMessages = List.from(messages);
      });
      return;
    }

    final searchQuery = query.toLowerCase().trim();

    setState(() {
      filteredMessages = messages.where((message) {
        final title = (message['title'] ?? '').toString().toLowerCase();
        final body = (message['body'] ?? '').toString().toLowerCase();
        final senderName =
        (message['sender']?['name'] ?? '').toString().toLowerCase();

        return title.contains(searchQuery) ||
            body.contains(searchQuery) ||
            senderName.contains(searchQuery);
      }).toList();
    });
  }

  Widget _buildPagination() {
    return Container(
      height: 25.sp,
      padding: EdgeInsets.symmetric(horizontal: 4.sp, vertical: 2.sp),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: currentPage > 1
                ? () {
              setState(() {
                currentPage--;
              });
              fetchMessages();
            }
                : null,
            child: Container(
              padding: EdgeInsets.all(2.sp),
              decoration: BoxDecoration(
                color: currentPage > 1 ? Colors.white24 : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 15.sp,
              ),
            ),
          ),
          SizedBox(width: 8.sp),
          DropdownButton<int>(
            value: currentPage <= totalPages ? currentPage : 1,
            dropdownColor: Colors.red.shade400,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(12),
            style: GoogleFonts.montserrat(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  currentPage = value;
                });
                fetchMessages();
              }
            },
            items: List.generate(
              totalPages == 0 ? 1 : totalPages,
                  (index) {
                final pageNumber = index + 1;
                return DropdownMenuItem<int>(
                  value: pageNumber,
                  child: Text(
                    "$pageNumber",
                    style: GoogleFonts.montserrat(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 8.sp),
          GestureDetector(
            onTap: currentPage < totalPages
                ? () {
              setState(() {
                currentPage++;
              });
              fetchMessages();
            }
                : null,
            child: Container(
              padding: EdgeInsets.all(2.sp),
              decoration: BoxDecoration(
                color: currentPage < totalPages
                    ? Colors.white24
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 15.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(dynamic message) {
    String formatted = '';

    try {
      if (message['created_at'] != null) {
        final dateTime = DateTime.parse(message['created_at'].toString());
        formatted = DateFormat('dd-MM-yyyy hh:mm a').format(dateTime);
      }
    } catch (_) {
      formatted = message['created_at']?.toString() ?? '';
    }

    final sender = message['sender'] ?? {};
    final senderName = sender['name']?.toString() ?? 'Sender';
    final senderPhoto = sender['photo']?.toString() ?? '';
    final title = message['title']?.toString() ?? '';
    final body = message['body']?.toString() ?? '';
    final attachment = message['attachment']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessageDetailScreen(
              userName: senderName,
              userImage: senderPhoto,
              partnerId: message['id'],
              classSection: title.isNotEmpty ? title : 'Message',
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(3.sp),
        child: Container(
          padding: EdgeInsets.all(6.sp),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: Colors.red.shade100,
                child: ClipOval(
                  child: senderPhoto.isNotEmpty
                      ? Image.network(
                    senderPhoto,
                    width: 32.r,
                    height: 32.r,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        size: 18.sp,
                        color: Colors.red,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Icon(
                        Icons.person,
                        size: 18.sp,
                        color: Colors.red,
                      );
                    },
                  )
                      : Icon(
                    Icons.person,
                    size: 18.sp,
                    color: Colors.red,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.black87,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (title.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: Colors.red.shade700,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    Text(
                      body.isNotEmpty
                          ? body.replaceAll('\n', ' ')
                          : attachment.isNotEmpty
                          ? 'Attachment'
                          : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.black54,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                formatted,
                style: GoogleFonts.montserrat(
                  color: Colors.grey,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Column(
        children: [
          SizedBox(height: 4.sp),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 5.sp),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Send ($totalChat)',
                    style: GoogleFonts.montserrat(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textwhite,
                    ),
                  ),
                ),
                SizedBox(width: 10.sp),
                _buildPagination(),
              ],
            ),
          ),
          //
          // SizedBox(height: 4.sp),
          //
          // Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 5.sp),
          //   child: TextField(
          //     controller: searchController,
          //     decoration: InputDecoration(
          //       hintText: 'Search by sender, title or message...',
          //       hintStyle: GoogleFonts.montserrat(
          //         fontSize: 11.sp,
          //         color: Colors.grey[600],
          //       ),
          //       prefixIcon: Icon(
          //         Icons.search,
          //         size: 20.sp,
          //         color: Colors.grey,
          //       ),
          //       suffixIcon: searchController.text.isNotEmpty
          //           ? IconButton(
          //         icon: const Icon(Icons.clear, color: Colors.grey),
          //         onPressed: () {
          //           searchController.clear();
          //           filterMessages('');
          //         },
          //       )
          //           : null,
          //       filled: true,
          //       fillColor: Colors.white,
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(10.sp),
          //         borderSide: BorderSide.none,
          //       ),
          //       contentPadding: EdgeInsets.symmetric(vertical: 10.sp),
          //     ),
          //     style: GoogleFonts.montserrat(
          //       fontSize: 11.sp,
          //       color: Colors.black,
          //       fontWeight: FontWeight.w600,
          //     ),
          //     onChanged: (value) {
          //       setState(() {});
          //       filterMessages(value);
          //     },
          //   ),
          // ),

          SizedBox(height: 4.sp),

          Expanded(
            child: isLoading
                ? WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? Center(
              child: DataNotFoundWidget(
                title: 'No messages found.',
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchMessages,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredMessages.length,
                itemBuilder: (context, index) {
                  final message = filteredMessages[index];
                  return _buildMessageCard(message);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}