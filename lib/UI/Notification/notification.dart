import 'package:avi/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../Auth/login_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isLoading = false;
  List notifications = [];

  @override
  void initState() {
    super.initState();
    fetchSubjectData();
  }

  Future<void> fetchSubjectData() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.notifications),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        notifications = jsonResponse['notifications'];
        isLoading = false;
      });
    } else {
      _showLoginDialog();
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Please log in again to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,

      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,

      ),
      body: isLoading
          ? WhiteCircularProgressWidget()
          : notifications.isEmpty
          ? Center(
          child: DataNotFoundWidget(
            title: 'Notification  Not Available.',
          ))
          : RefreshIndicator(
        onRefresh: fetchSubjectData,
        child: ListView.builder(
          padding: const EdgeInsets.all(0.0),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              child: ListTile(
                contentPadding:  EdgeInsets.all(3),
                leading: Container(
                  width: 30.sp,
                  height: 30.sp,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:  Icon(Icons.notifications, color: AppColors.primary),
                ),
                title: Text(
                  notification['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: notification['isRead'] == true ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['description'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 11.sp),
                      ),
                      Text(
                        notification['date'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // trailing: notification['attachment'] != null
                //     ?  Icon(Icons.attachment, color: AppColors.primary)
                //     : null,
              ),
            );
          },
        ),
      ),



    );
  }
}
