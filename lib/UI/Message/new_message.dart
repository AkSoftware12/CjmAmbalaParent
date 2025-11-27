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

class NewMesssageScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;
  const NewMesssageScreen({super.key, required this.messageSendPermissionsApp});

  @override
  State<NewMesssageScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<NewMesssageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  List messsage = [];
  List filteredMessages = []; // List for filtered results

  @override
  void initState() {
    super.initState();
    DateTime.now().subtract(const Duration(days: 30));
    fetchAssignmentsData();
    _searchController.addListener(_filterMessages); // Listen to search input
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true;
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
        messsage = jsonResponse['users'];
        filteredMessages = messsage; // Initialize filtered list
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterMessages() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredMessages = messsage.where((assignment) {
        final name = assignment['first_name'].toString().toLowerCase();
        final designation = assignment['designation']['title'].toString().toLowerCase();
        return name.contains(query) || designation.contains(query);
      }).toList();
    });
  }

  Future<void> _sendMessage(String msg, int senderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final uri = Uri.parse(ApiRoutes.sendMessage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['receivers[]'] = 'user_$senderId';
      request.fields['body'] = msg;

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
      } else {
        // Handle error
      }
    } catch (e) {
      // Handle exception
    }
  }

  void _showMessagePopup(BuildContext context, String name, String subtitle, int id) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController messageController = TextEditingController();

        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send Message\n($name)',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          content: TextField(
            controller: messageController,
            decoration: InputDecoration(
              hintText: 'Type your message here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 4,
            keyboardType: TextInputType.multiline,
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                String message = messageController.text.trim();
                if (message.isNotEmpty) {
                  _sendMessage(message, id);
                  print('Sending message to $name: $message');
                  Navigator.of(dialogContext).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a message'),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Send',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 8.0,
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Permission Denied',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Sorry, you don\'t have permission to send messages at this time. Please contact support for assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: AppColors.textwhite),
        backgroundColor: AppColors.secondary,
        title: Text(
          'New Messages',
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            color: AppColors.textwhite,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 8.sp),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or designation...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterMessages();
                  },
                )
                    : null,
              ),
            ),
          ),
          // List View
          Expanded(
            child: isLoading
                ? const WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? const Center(
              child: DataNotFoundWidget(
                title: 'No Users Found.',
              ),
            )
                : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final assignment = filteredMessages[index];
                return GestureDetector(
                  onTap: () {
                    if (widget.messageSendPermissionsApp == 0) {
                      _showPermissionDeniedPopup(context);
                    } else {
                      _showMessagePopup(
                        context,
                        assignment['first_name'],
                        assignment['designation']['title'].toString(),
                        assignment['id'],
                      );
                    }
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(vertical: 3.sp, horizontal: 8.sp),
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
                                child: const Center(
                                  child: Icon(
                                    Icons.chat,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.sp),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${assignment['first_name'].toString().toUpperCase()}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '(${assignment['designation']['title'].toString().toUpperCase()})',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
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

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}