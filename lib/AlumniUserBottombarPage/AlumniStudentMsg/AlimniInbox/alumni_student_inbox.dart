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
import '../../alumni_chat_screen.dart';

class AlumniStudentInboxScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const AlumniStudentInboxScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<AlumniStudentInboxScreen> createState() => _StudentInboxScreenState();
}

class _StudentInboxScreenState extends State<AlumniStudentInboxScreen> {
  bool isLoading = false;
  bool isFetching = false;

  List messages = [];
  Map<String, dynamic>? principalData;

  int currentPage = 1;
  int totalPages = 1;
  int totalChat = 0;

  @override
  void initState() {
    super.initState();
    fetchInboxData();
  }

  Future<void> fetchInboxData() async {
    if (isFetching) return;
    isFetching = true;

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('alumniToken');

      if (token == null || token.isEmpty) {
        messages = [];
        principalData = null;
      } else {
        final url = Uri.parse('${ApiRoutes.getAlumniInbox}?page=$currentPage');

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['status'] == 'success') {
            messages = jsonResponse['data'] ?? [];
            principalData = jsonResponse['principal'];
            totalPages = jsonResponse['pagination']?['last_page'] ?? 1;
            totalChat = jsonResponse['pagination']?['total'] ?? messages.length;
          } else {
            messages = [];
            principalData = null;
          }
        } else {
          messages = [];
          principalData = null;
        }
      }
    } catch (e) {
      messages = [];
      principalData = null;
    }

    isFetching = false;
    if (mounted) setState(() => isLoading = false);
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox();

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
              currentPage--;
              fetchInboxData();
            }
                : null,
            child: Container(
              padding: EdgeInsets.all(2.sp),
              decoration: BoxDecoration(
                color: currentPage > 1 ? Colors.white24 : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_left, color: Colors.white, size: 15.sp),
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
              if (value != null && value != currentPage) {
                currentPage = value;
                fetchInboxData();
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
              currentPage++;
              fetchInboxData();
            }
                : null,
            child: Container(
              padding: EdgeInsets.all(2.sp),
              decoration: BoxDecoration(
                color: currentPage < totalPages ? Colors.white24 : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right, color: Colors.white, size: 15.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(dynamic item) {
    final latestMessage = item['latest_message'] ?? {};

    String formatted = '';
    try {
      if (latestMessage['created_at'] != null) {
        final dateTime = DateTime.parse(latestMessage['created_at'].toString());
        formatted = DateFormat('dd-MM-yyyy hh:mm a').format(dateTime);
      }
    } catch (_) {}

    final unreadCount =
        int.tryParse((item['unread_count'] ?? '0').toString()) ?? 0;

    final String senderType = (item['sender_type'] ?? '').toString();
    final bool isPrincipal = senderType.toLowerCase() == 'principal';

    final String displayName = isPrincipal
        ? (principalData?['name'] ?? senderType).toString()
        : senderType.toUpperCase();

    final String designation =
    isPrincipal ? (principalData?['designation'] ?? '').toString() : '';

    final String photoUrl = (isPrincipal && principalData != null)
        ? (principalData!['photo']?.toString() ?? '')
        : '';
    final String messageText = (latestMessage['message'] != null &&
        latestMessage['message'].toString().trim().isNotEmpty)
        ? latestMessage['message'].toString()
        : (latestMessage['attachment'] != null ? 'Attachment' : '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlumniStudentChatScreen(
            ),
          ),
        ).then((_) => fetchInboxData());
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 3.sp, horizontal: 5.sp),
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.sp),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.sp),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50.withOpacity(.35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 5.sp, vertical: 5.sp),
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.sp),
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                      photoUrl,
                      height: 40.sp,
                      width: 40.sp,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultImage(),
                    )
                        : _defaultImage(),
                  ),
                  SizedBox(width: 10.sp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        if (designation.isNotEmpty)
                          Text(
                            designation,
                            style: GoogleFonts.montserrat(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (messageText.isNotEmpty)
                          Text(
                            messageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        if (formatted.isNotEmpty)
                          Text(
                            formatted,
                            style: GoogleFonts.montserrat(
                              fontSize: 8.8.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 15.sp, color: Colors.black54),
                ],
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                    EdgeInsets.symmetric(horizontal: 5.sp, vertical: 2.sp),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: GoogleFonts.montserrat(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultImage() {
    return Container(
      height: 40.sp,
      width: 40.sp,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white),
    );
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
                    'Inbox ($totalChat)',
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
          SizedBox(height: 4.sp),
          Expanded(
            child: isLoading
                ? WhiteCircularProgressWidget()
                : messages.isEmpty
                ? Center(
              child: DataNotFoundWidget(title: 'No chats found.'),
            )
                : RefreshIndicator(
              onRefresh: fetchInboxData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    _buildMessageCard(messages[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}