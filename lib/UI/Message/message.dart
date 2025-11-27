import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../constants.dart';
import 'chat.dart';
import 'new_message.dart';

class MesssageListScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;
  const MesssageListScreen({super.key, required this.messageSendPermissionsApp});

  @override
  State<MesssageListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<MesssageListScreen> {
  bool isLoading = false;
  List messsage = []; // Original list to hold API data
  List filteredMessages = []; // Filtered list for search
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DateTime.now().subtract(const Duration(days: 30));
    fetchAssignmentsData();
    // Initialize filteredMessages with the original messsage list
    filteredMessages = messsage;
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getAllMessages),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        messsage = jsonResponse['conversations']; // Update state with fetched data
        filteredMessages = messsage; // Initialize filtered list
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
        filteredMessages = messsage; // Reset to original list if query is empty
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
    searchController.dispose(); // Dispose of the TextEditingController
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
          // Navigate to NewMesssageScreen and refresh API on return
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewMesssageScreen(
                messageSendPermissionsApp: widget.messageSendPermissionsApp,
              ),
            ),
          ).then((value) {
            // Refresh API data when returning from NewMesssageScreen
            fetchAssignmentsData();
          });
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 10.sp),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or designation...',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(Icons.search, size: 20.sp, color: Colors.grey),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear(); // Clear the search text
                    filterMessages(''); // Reset the filtered messages
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
              style: GoogleFonts.montserrat(fontSize: 12.sp),
              onChanged: (value) {
                filterMessages(value); // Call filter function on text change
              },
            ),
          ),
          // Message List
          Expanded(
            child: isLoading
                ? WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? Center(
              child: DataNotFoundWidget(
                title: 'No chats found.',
              ),
            )
                : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final assignment = filteredMessages[index];

                return GestureDetector(
                  onTap: () {
                    // Navigate to ChatScreen and refresh API on return
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          id: assignment['base_message_id'],
                          messageSendPermissionsApp:
                          widget.messageSendPermissionsApp,
                          name: assignment['partner_name'],
                          msgSendId: assignment['partner_id'],
                          designation:
                          assignment['partner_designation'].toString(),
                        ),
                      ),
                    ).then((value) {
                      // Refresh API data when returning from ChatScreen
                      fetchAssignmentsData();
                    });
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(
                        vertical: 3.sp, horizontal: 8.sp),
                    elevation: 6,
                    color: Colors.white, // Light background
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11.sp),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// **Title & Index**
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
                                    Icons.chat, // Material chat icon
                                    size: 20.sp, // Adjust size as needed
                                    color: Colors.white, // Match original text color
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
                                      '${assignment['partner_name'].toString().toUpperCase()}(${assignment['partner_designation'].toString().toUpperCase()})',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      assignment['last_message_at'].toString(),
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