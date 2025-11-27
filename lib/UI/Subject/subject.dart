import 'dart:convert';

import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../Auth/login_screen.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<SubjectScreen> {

  bool isLoading = false;
  List subject = []; // Declare a list to hold API data


  @override
  void initState() {
    super.initState();

    DateTime.now().subtract(const Duration(days: 30));

    fetchSubjectData();
  }


  Future<void> fetchSubjectData() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getSubject),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        subject = jsonResponse['data'];
        isLoading = false; // Stop progress bar
// Update state with fetched data
      });
    } else {
      _showLoginDialog();
      setState(() {
        isLoading = true; // Show progress bar
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
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'All Subject',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Set text color to white

          ),
        ),
        backgroundColor: AppColors.primary,
      ),
      body:isLoading
          ? WhiteCircularProgressWidget()
          : subject.isEmpty
          ? Center(child: DataNotFoundWidget(title: 'Subject  Not Available.',))
          :  ListView.builder(
          itemCount: subject.length,
          itemBuilder: (context, index) {
            final schedule = subject[index];
            return Card(
              elevation: 3,
              color:HexColor('#f2888c'),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // Rounded corners
                side: BorderSide(
                  color: Colors.black54, // Border color
                  width: 1, // Border width
                ),
              ),
              child: ListTile(
                title: Text(
                  schedule['subject_name'],
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Row(
                  children: [

                    // SizedBox(
                    //     height: 18,
                    //     width: 18,
                    //     child: Image.asset('assets/teacher.png',color: Colors.black,)),
                    Text(
                      " ${schedule['teacher_name']??'N/A'}",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade200,
                      ),
                    ),

                  ],
                ),

                leading: SizedBox(
                    width: 50,
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Image.asset('assets/physics.png',),
                    )),

              ),
            );
          },
        ),

    );
  }
}

