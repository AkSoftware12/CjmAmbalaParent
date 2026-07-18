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

class AlumniUserProfileScreen extends StatefulWidget {
  const AlumniUserProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<AlumniUserProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? alumniData;
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

  /// Safely read a value from the alumni map as a trimmed string.
  /// Handles nulls, ints and the trailing spaces the API sends
  /// (e.g. "07-02-2004   ").
  String _field(String key) {
    final value = alumniData?[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<void> fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getProfileAlumniUser),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (!mounted) return;
        setState(() {
          // API returns { "success": true, "alumni": { ... } }
          alumniData = data['alumni'];
          isLoading = false;
          _controller.forward();
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.secondary,
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade500,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        },
      ),
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   title: Text(
      //     'Profile',
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontSize: 20.sp,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      //   backgroundColor: AppColors.secondary,
      // ),
      body: isLoading
          ? _buildShimmerLoading()
          : alumniData == null
          ? const Center(
        child: Text(
          'Could not load profile',
          style: TextStyle(color: Colors.white),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: AnimatedOpacity(
          opacity: isLoading ? 0 : 1,
          duration: const Duration(seconds: 1),
          child: Column(
            children: [
              // ---------- Header ----------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar (no picture in alumni API → logo)
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.sp),
                          border: Border.all(width: 1.sp,color: Colors.grey.shade200)
                        ),
                        child: Image.asset(
                          AppAssets.cjmlogo,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 150,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisAlignment:
                        MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            _field('full_name').isNotEmpty
                                ? _field('full_name')
                                : 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _field('email').isNotEmpty
                                ? _field('email')
                                : 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.red.shade500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _field('phone').isNotEmpty
                                ? _field('phone')
                                : 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.red.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildAnimatedSection('Personal Information', [
                buildProfileRow('Name', _field('full_name')),
                buildProfileRow(
                  'Date of Birth',
                  _field('date_of_birth'),
                ),
                buildProfileRow('Email', _field('email')),
                buildProfileRow('Phone', _field('phone')),
                buildProfileRow('Address', _field('address')),
                buildProfileRow('City', _field('city')),
              ]),

              const SizedBox(height: 20),
              _buildAnimatedSection('School Information', [
                buildProfileRow(
                  'Year of Passing',
                  _field('year_of_passing'),
                ),
                buildProfileRow(
                  'Class Passed',
                  _field('class_passed'),
                ),
                buildProfileRow('Section', _field('section')),
                buildProfileRow('House', _field('house')),
                buildProfileRow(
                  'Favourite Subject',
                  _field('favourite_subject'),
                ),
                buildProfileRow(
                  'Favourite Teacher',
                  _field('favourite_teacher'),
                ),
              ]),

              const SizedBox(height: 20),
              _buildAnimatedSection('Professional Information', [
                buildProfileRow('Occupation', _field('occupation')),
                buildProfileRow(
                  'Organisation',
                  _field('organisation'),
                ),
              ]),

              const SizedBox(height: 20),
              _buildAnimatedSection('Account', [
                buildProfileRow('Username', _field('username')),
              ]),


              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const LoginUserLIst(),
              //       ),
              //     );
              //   },
              //   child: Card(
              //     child: Padding(
              //       padding: const EdgeInsets.all(15.0),
              //       child: Center(
              //         child: Row(
              //           mainAxisAlignment: MainAxisAlignment.center,
              //           children: [
              //             const Icon(
              //               Icons.account_circle,
              //               size: 20,
              //               color: Colors.black,
              //             ),
              //             SizedBox(width: 5.sp),
              //             Text(
              //               'Users List',
              //               style: TextStyle(
              //                 color: Colors.black,
              //                 fontSize: 12.sp,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 20),
              //
              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const LoginPage(),
              //       ),
              //     );
              //   },
              //   child: Card(
              //     child: Padding(
              //       padding: const EdgeInsets.all(8.0),
              //       child: Center(
              //         child: Column(
              //           children: [
              //             Row(
              //               mainAxisAlignment:
              //               MainAxisAlignment.center,
              //               children: [
              //                 const Icon(
              //                   Icons.add_circle_outline,
              //                   size: 20,
              //                   color: Colors.black,
              //                 ),
              //                 SizedBox(width: 5.sp),
              //                 Text(
              //                   'Add Account',
              //                   style: TextStyle(
              //                     color: Colors.black,
              //                     fontSize: 12.sp,
              //                     fontWeight: FontWeight.bold,
              //                   ),
              //                 ),
              //               ],
              //             ),
              //             Text(
              //               'Add another account',
              //               style: TextStyle(
              //                 color: Colors.grey,
              //                 fontSize: 10.sp,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection(String title, List<Widget> rows) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.grey, blurRadius: 10, spreadRadius: 2),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label :",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textwhite,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: TextStyle(color: AppColors.textwhite),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return const Center(child: CupertinoActivityIndicator(radius: 20));
  }
}