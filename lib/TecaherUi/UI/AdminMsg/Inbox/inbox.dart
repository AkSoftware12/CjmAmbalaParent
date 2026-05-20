import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonCalling/data_not_found.dart';
import '../../../../CommonCalling/progressbarWhite.dart';
import '../../../../constants.dart';
import '../../TeacherMessage/chat.dart';



class InboxScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const InboxScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<InboxScreen> createState() =>
      _TeacherMesssageListScreenState();
}

class _TeacherMesssageListScreenState
    extends State<InboxScreen> {
  bool isLoading = false;

  List messsage = [];
  List filteredMessages = [];

  TextEditingController searchController = TextEditingController();

  int currentPage = 1;
  int totalPages = 1;
  int totalChat = 0;

  String selectedFilter = "all"; // all, read, unread

  @override
  void initState() {
    super.initState();
    fetchAssignmentsData();
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      Uri url;

      if (selectedFilter == "all") {
        url = Uri.parse(
          '${ApiRoutes.getInboxList}?page=$currentPage',
        );
      } else {
        url = Uri.parse(
          '${ApiRoutes.getInboxList}?page=$currentPage&filter=$selectedFilter',
        );
      }

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        messsage = jsonResponse['conversations'] ?? [];
        totalPages = jsonResponse['pagination']?['last_page'] ?? 1;
        totalChat = jsonResponse['pagination']?['total'] ?? 0;

        filterMessages(searchController.text);

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          messsage = [];
          filteredMessages = [];
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        messsage = [];
        filteredMessages = [];
      });
    }
  }

  void filterMessages(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredMessages = List.from(messsage);
      });
      return;
    }

    final searchQuery = query.toLowerCase().trim();

    setState(() {
      filteredMessages = messsage.where((message) {
        final partnerName =
        (message['partner_name'] ?? '').toString().toLowerCase();
        final partnerDesignation =
        (message['partner_designation'] ?? '').toString().toLowerCase();
        final partnerClass =
        (message['partnerclass'] ?? '').toString().toLowerCase();
        final partnerSection =
        (message['partnersection'] ?? '').toString().toLowerCase();
        final lastMessage =
        (message['last_message'] ?? '').toString().toLowerCase();

        return partnerName.contains(searchQuery) ||
            partnerDesignation.contains(searchQuery) ||
            partnerClass.contains(searchQuery) ||
            partnerSection.contains(searchQuery) ||
            lastMessage.contains(searchQuery);
      }).toList();
    });
  }

  Widget _filterChip(String title, String value) {
    final bool isSelected = selectedFilter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedFilter == value) return;

          setState(() {
            selectedFilter = value;
            currentPage = 1;
          });

          fetchAssignmentsData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          padding: EdgeInsets.symmetric(vertical: 3.h),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [
                Color(0xFFE53935),
                Color(0xFFD32F2F),
              ],
            )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.red.withOpacity(0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.montserrat(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              child: Text(title),
            ),
          ),
        ),
      ),
    );
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
            onTap: () {
              if (currentPage > 1) {
                setState(() {
                  currentPage--;
                });
                fetchAssignmentsData();
              }
            },
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
            alignment: Alignment.center,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  currentPage = value;
                });
                fetchAssignmentsData();
              }
            },
            items: List.generate(
              totalPages == 0 ? 1 : totalPages,
                  (index) {
                final pageNumber = index + 1;
                return DropdownMenuItem<int>(
                  value: pageNumber,
                  child: Center(
                    child: Text(
                      "$pageNumber",
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 8.sp),
          GestureDetector(
            onTap: () {
              if (currentPage < totalPages) {
                setState(() {
                  currentPage++;
                });
                fetchAssignmentsData();
              }
            },
            child: Container(
              padding: EdgeInsets.all(2.sp),
              decoration: BoxDecoration(
                color: currentPage < totalPages ? Colors.white24 : Colors.white10,
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

  Widget _buildMessageCard(dynamic assignment) {
    DateTime? dateTime;
    String formatted = '';

    try {
      if (assignment['last_message_at'] != null) {
        dateTime = DateTime.parse(assignment['last_message_at'].toString());
        formatted = DateFormat('dd-MM-yyyy hh:mm a').format(dateTime);
      }
    } catch (_) {
      formatted = '';
    }

    final unreadCount =
        int.tryParse((assignment['unread_count'] ?? '0').toString()) ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherChatScreen(
              id: assignment['base_message_id'],
              messageSendPermissionsApp: widget.messageSendPermissionsApp,
              name: assignment['partner_name'],
              msgSendId: assignment['partner_id'].toString(),
              designation:
              '${assignment['partnerclass'].toString()}(${assignment['partnersection'].toString()})',
            ),
          ),
        ).then((value) {
          fetchAssignmentsData();
        });
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
              colors: [
                Colors.white,
                Colors.blue.shade50.withOpacity(.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 5.sp,
              vertical: 5.sp,
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    /// Profile Icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.sp),
                      child: assignment['sender_image'] != null &&
                          assignment['sender_image'].toString().isNotEmpty
                          ? Image.network(
                        assignment['sender_image'].toString(),
                        height: 40.sp,
                        width: 40.sp,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 40.sp,
                          width: 40.sp,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.secondary,
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                      )
                          :Container(
                        height: 40.sp,
                        width: 40.sp,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.sp),

                    /// Text Area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// Name + Date Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (assignment['partner_name'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (formatted.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(left: 0.sp),
                                  child: Text(
                                    formatted,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8.8.sp,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),


                            ],
                          ),
                          if (assignment['partnerclass'].isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 0.sp),
                              child: Text(
                                '${assignment['partnerclass']} (${assignment['partnersection']})',
                                style: GoogleFonts.montserrat(
                                  fontSize: 8.8.sp,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),


                          /// Last Message
                          Row(
                            children: [
                              // Icon(
                              //   Icons.done_all,
                              //   color: Colors.red,
                              //   size: 14.sp,
                              // ),
                              // SizedBox(width: 4.sp),
                              Expanded(
                                child: Text(
                                  assignment['last_message'] != null
                                      ? assignment['last_message'].toString()
                                      : 'Attachment',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                    Center(child: Icon(Icons.arrow_forward_ios,size: 15,))


                  ],
                ),

                /// Unread Badge
                if (unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.sp,
                        vertical: 2.sp,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(.35),
                            blurRadius: 6,
                          )
                        ],
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
      )
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          //
          // Container(
          //   margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.h),
          //   padding: EdgeInsets.all(2.w),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     borderRadius: BorderRadius.circular(5.r),
          //   ),
          //   child: Row(
          //     children: [
          //       _filterChip("All", "all"),
          //       _filterChip("Read", "read"),
          //       _filterChip("Unread", "unread"),
          //     ],
          //   ),
          // ),
          // SizedBox(height: 8.sp),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.sp, vertical: 0.sp),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, class, section or message...',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 11.sp,
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20.sp,
                  color: Colors.grey,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear();
                    filterMessages('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.sp),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.sp),
              ),
              style: GoogleFonts.montserrat(
                fontSize: 11.sp,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (value) {
                setState(() {});
                filterMessages(value);
              },
            ),
          ),

          SizedBox(height: 4.sp),

          Expanded(
            child: isLoading
                ? WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? Center(
              child: DataNotFoundWidget(
                title: 'No chats found.',
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchAssignmentsData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredMessages.length,
                itemBuilder: (context, index) {
                  final assignment = filteredMessages[index];
                  return _buildMessageCard(assignment);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}