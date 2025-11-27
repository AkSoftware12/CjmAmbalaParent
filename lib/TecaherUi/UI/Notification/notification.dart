import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../constants.dart';
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
    final token = prefs.getString('teachertoken');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.Teachernotifications),
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
      appBar: AppBar(
        backgroundColor: AppColors2.primary,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade200],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CupertinoActivityIndicator(
          radius: 20,
          color: Colors.black54,
        ))
            : RefreshIndicator(
          onRefresh: fetchSubjectData,
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors2.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(Icons.notifications, color: Colors.black54),
                  ),
                  title: Text(
                    notification['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: notification['isRead'] == true ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['description'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['date'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: notification['attachment'] != null
                      ?  Icon(Icons.attachment, color: AppColors2.primary)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
