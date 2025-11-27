import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../CommonCalling/progressbarWhite.dart';
import '../../../constants.dart';
import 'bottomsheet_new_message.dart';
import 'chat.dart';

class TeacherMesssageListScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const TeacherMesssageListScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<TeacherMesssageListScreen> createState() =>
      _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<TeacherMesssageListScreen> {
  bool isLoading = false;
  List messsage = []; // Original list to hold API data
  List filteredMessages = []; // Filtered list for search
  TextEditingController searchController = TextEditingController();
  int currentPage = 1; // default page
  int totalPages = 1; // Initialize to 1, update from API response
  int totalChat = 0; // Initialize to 1, update from API response

  @override
  void initState() {
    super.initState();
    fetchAssignmentsData();
    filteredMessages = messsage;
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    print("Token: $token");

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Append currentPage to the API URL as a query parameter
    final response = await http.get(
      Uri.parse('${ApiRoutes.getAllTeacherMessages}?page=$currentPage'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        messsage = jsonResponse['conversations'] ?? []; // Update with fetched data
        filteredMessages = messsage; // Update filtered list
        // Update totalPages from API response (adjust key based on your API)
        totalPages = jsonResponse['pagination']['last_page'] ?? 1; // Example key, adjust as needed
        totalChat = jsonResponse['pagination']['total'] ?? 1; // Example key, adjust as needed
        isLoading = false; // Stop progress bar
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Search filter function
  void filterMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredMessages = messsage; // Reset to original list
      });
      return;
    }

    setState(() {
      filteredMessages = messsage.where((message) {
        final partnerName = message['partner_name'].toString().toLowerCase();
        final partnerDesignation = message['partner_designation'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return partnerName.contains(searchQuery) || partnerDesignation.contains(searchQuery);
      }).toList();
    });
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
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.textwhite),
        backgroundColor: AppColors.secondary,
        title: Text(
          'Messages',
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            color: AppColors.textwhite,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          'New Message',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewTeacherMessageScreen(
                messageSendPermissionsApp: widget.messageSendPermissionsApp,
              ),
            ),
          ).then((value) {
            fetchAssignmentsData(); // Refresh API data
          });
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 0.sp),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or designation... ',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(Icons.search, size: 20.sp, color: Colors.grey),
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
                fontSize: 12.sp,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (value) {
                filterMessages(value);
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 10.sp),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Conversations text
                Text(
                  'Conversations (${totalChat})',
                  style: GoogleFonts.montserrat(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textwhite,
                  ),
                ),

                // Pagination controls
                Container(
                  height: 30.sp,
                  padding: EdgeInsets.symmetric(horizontal: 3.sp, vertical: 2.sp),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Left Arrow
                      GestureDetector(
                        onTap: () {
                          if (currentPage > 1) {
                            setState(() {
                              currentPage--;
                              fetchAssignmentsData(); // Trigger API call
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(1.sp),
                          decoration: BoxDecoration(
                            color: currentPage > 1 ? Colors.white24 : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                        ),
                      ),

                      SizedBox(width: 10.sp),

                      // Page Number
                      DropdownButton<int>(
                        value: currentPage,
                        dropdownColor: Colors.red.shade400, // dropdown background white
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        underline: const SizedBox(), // 👈 नीचे की लाइन हटाने के लिए
                        borderRadius: BorderRadius.circular(12),




                        // 👉 Selected value का style (closed dropdown)
                        style: GoogleFonts.montserrat(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange, // selected value white रहे
                        ),
                        alignment: Alignment.center,

                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              currentPage = value; // ✅ Page update
                            });
                            fetchAssignmentsData(); // API call
                          }
                        },

                        // 👉 Dropdown खुलने पर items का style black
                        items: List.generate(totalPages, (index) {
                          final pageNumber = index + 1;
                          return DropdownMenuItem<int>(
                            value: pageNumber,
                            child: Align(
                              alignment: Alignment.center, // ✅ center me la diya
                              child: Text(
                                "$pageNumber",
                                style: GoogleFonts.montserrat(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white, // ✅ open list me black color
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      SizedBox(width: 10.sp),

                      // Right Arrow
                      GestureDetector(
                        onTap: () {
                          if (currentPage < totalPages) {
                            setState(() {
                              currentPage++;
                              fetchAssignmentsData(); // Trigger API call
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(1.sp),
                          decoration: BoxDecoration(
                            color: currentPage < totalPages ? Colors.white24 : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: isLoading
                ? WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? Center(child: DataNotFoundWidget(title: 'No chats found.'))
                : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final assignment = filteredMessages[index];
                DateTime dateTime = DateTime.parse(
                  assignment['last_message_at'].toString(),
                );

                String formatted = DateFormat(
                  'dd-MM-yyyy hh:mm a',
                ).format(dateTime);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherChatScreen(
                          id: assignment['base_message_id'],
                          messageSendPermissionsApp:
                          widget.messageSendPermissionsApp,
                          name: assignment['partner_name'],
                          msgSendId: assignment['partner_id'],
                          designation:
                          '${assignment['partnerclass'].toString()}(${assignment['partnersection'].toString()})',
                        ),
                      ),
                    ).then((value) {
                      fetchAssignmentsData(); // Refresh API data
                    });
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(
                      vertical: 3.sp,
                      horizontal: 8.sp,
                    ),
                    elevation: 6,
                    color: Colors.white,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11.sp),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 35.sp,
                                width: 35.sp,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.chat,
                                    size: 20.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.sp),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // '${assignment['partner_name'].toString().toUpperCase()} ${index+1}',
                                      '${assignment['partner_name'].toString().toUpperCase()}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Class: ${assignment['partnerclass'] ?? 'N/A'} , Section: ${assignment['partnersection'] ?? 'N/A'}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      formatted,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    if (assignment['last_message'] != null)
                                      Text(
                                        assignment['last_message'].toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    if (assignment['last_message'] == null)
                                      Text(
                                        'Attachment',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}