import 'package:avi/HexColorCode/HexColor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../constants.dart';
import '../UI/Auth/login_student_userlist.dart';
import '/UI/Auth/login_screen.dart';

class NewUserProfileScreen extends StatefulWidget {
  const NewUserProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<NewUserProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    fetchProfileData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('newusertoken');
    print("token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfileNewUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return; // ✅ stop here if widget is gone

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (!mounted) return; // ✅ double-check before setState
      setState(() {
        studentData = data['student'];
        isLoading = false;
        _controller.forward(); // Start animation once data is loaded
      });
    } else {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade500,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear(); // Clear the stored token
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );

        },
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          Card(
            // elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () async {
                final Uri uri = Uri.parse(
                  '${ApiRoutes.admissionDownload}${studentData!['id']}',
                );
                try {
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open URL')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HexColor('61045F'), HexColor('AA076B')],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.print, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Admission Form Print',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      body: isLoading
          ? _buildShimmerLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedOpacity(
                opacity: isLoading ? 0 : 1,
                duration: const Duration(seconds: 1),
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                        // border: Border.all(
                        //   color: Colors.black, // Change this to your desired border color
                        //   width: 1,           // Border width
                        // ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Image
                          SizedBox(
                            height: 120,
                            width: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                studentData!['picture_data'] ?? '',
                                // Use an empty string if the photo is null
                                fit: BoxFit.fill,
                                errorBuilder: (context, error, stackTrace) {
                                  // This widget will be displayed if the image fails to load
                                  return Container(
                                    height: 120,
                                    width: 120,
                                    color: Colors.white,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset(
                                        AppAssets.cjmlogo,
                                        // Assuming AppAssets.logo is a string path to an asset
                                        fit: BoxFit
                                            .cover, // Ensures the logo fills the avatar space
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // User Info
                          Expanded(
                            child: Container(
                              height: 150,
                              child: Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 10),

                                    Text(
                                      studentData!['name'] ?? 'N/A',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      studentData!['email'] ?? 'N/A',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      studentData!['contact'] ?? 'N/A',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildAnimatedSection('Personal Information', [
                      buildProfileRow('Name', studentData!['name'] ?? ''),
                      buildProfileRow(
                        'Date of Birth',
                        studentData!['dob'] ?? '',
                      ),
                      buildProfileRow(
                        'Gender',
                        studentData!['gender'] == '1' ? 'Male' : 'Female',
                      ),
                      buildProfileRow(
                        'Nationality',
                        studentData!['nationality'] ?? '',
                      ),
                      buildProfileRow(
                        'Blood Group',
                        studentData!['blood_group'].toString() ?? '',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildAnimatedSection('Academic Information', [
                      buildProfileRow(
                        'Class',
                        studentData!['class_name'] ?? 'N/A',
                      ),
                      buildProfileRow('Section', studentData!['section'] ?? ''),
                      buildProfileRow(
                        'Roll Number',
                        studentData!['roll_no'] ?? '',
                      ),
                      // buildProfileRow(
                      //   'Registration Number',
                      //   studentData!['registration_no']??'',
                      // ),
                      buildProfileRow(
                        'Admission Number',
                        studentData!['unique_id'] ?? '',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildAnimatedSection('Contact Information', [
                      buildProfileRow(
                        'Contact Person',
                        studentData!['contact_person'] ?? '',
                      ),
                      buildProfileRow(
                        'Contact Number',
                        studentData!['contact'] ?? '',
                      ),
                      buildProfileRow('Email', studentData!['email'] ?? ''),
                      buildProfileRow('Address', studentData!['address'] ?? ''),
                    ]),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: (){

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginUserLIst(),
                          ),
                        );

                      },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.account_circle,size: 20,color: Colors.black,),
                                    SizedBox(width: 5.sp,),
                                    Text('Users List',style: TextStyle(color: Colors.black,fontSize: 12.sp,fontWeight: FontWeight.bold),)

                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: (){

                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );

                      },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline,size: 20,color: Colors.black,),
                                    SizedBox(width: 5.sp,),
                                    Text('Add Account',style: TextStyle(color: Colors.black,fontSize: 12.sp,fontWeight: FontWeight.bold),)

                                  ],
                                ),
                                Text('Add another account',style: TextStyle(color: Colors.grey,fontSize: 10.sp),)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnimatedSection(String title, List<Widget> rows) {
    return AnimatedContainer(
      duration: const Duration(seconds: 10 ),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color:Colors.black54,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textwhite,
            ),
          ),
          const SizedBox(height: 10),
          Column(children: rows),
        ],
      ),
    );
  }

  Widget buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // Align the row to start
          children: [
            Text(
              "$label :",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textwhite,
              ),
            ),
            const SizedBox(width: 10), // Add some space between label and value
            Expanded(
              child: Text(
                value.isNotEmpty ? value : 'N/A',
                overflow: TextOverflow.visible,
                style: TextStyle(color: AppColors.textwhite),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(child: CupertinoActivityIndicator(radius: 20));
  }
}
