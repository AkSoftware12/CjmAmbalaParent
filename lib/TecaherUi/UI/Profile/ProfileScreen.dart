import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../UI/Auth/login_student_userlist.dart';
import '../../../constants.dart';
import '/UI/Auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? teacherData;

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
    final token = prefs.getString('teachertoken');
    print("token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getTeacheProfile),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        teacherData = data['teacher'];
        isLoading = false;
        _controller.forward(); // Start animation once data is loaded
      });
    } else {
      _showLoginDialog();
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
              Navigator.of(ctx).pop(); // Close dialog
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
      backgroundColor: AppColors2.primary,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
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
                padding:  EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration:  BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors2.primary, AppColors2.primary],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
                          teacherData?['photo'] ?? '', // Use an empty string if the photo is null
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
                                  AppAssets.cjmlogo,  // Assuming AppAssets.logo is a string path to an asset
                                  fit: BoxFit.cover,  // Ensures the logo fills the avatar space
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    ),
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
                                '${teacherData?['first_name']??''} ${teacherData?['last_name']??''}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:AppColors2.textblack,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                teacherData?['email']??'',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                teacherData?['phone']??'',
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
                buildProfileRow('Name', '${teacherData?['first_name']??''} ${teacherData?['last_name']??''}'),
                buildProfileRow('Date of Birth', teacherData?['dob']??''),
                buildProfileRow('Qualification', teacherData?['qualification']??''),
                buildProfileRow('Experience', teacherData?['experience']??''),
                buildProfileRow('Gender', teacherData?['gender'] == '1' ? 'Male' : 'Female',
                ),
                buildProfileRow('Nationality', teacherData?['nationality']?? ''),
                buildProfileRow('Blood Group', teacherData?['blood_group'].toString()??''),
              ]),
              // const SizedBox(height: 20),
              // _buildAnimatedSection('Academic Information', [
              //   buildProfileRow('Class', teacherData?['class_name']??''),
              //   buildProfileRow('Section', teacherData?['section']?? ''),
              //   buildProfileRow('Roll Number', teacherData?['roll_no']??''),
              //   buildProfileRow(
              //     'Registration Number',
              //     teacherData?['registration_no']??'',
              //   ),
              //   buildProfileRow('Admission Number', teacherData?['adm_no']??''),
              // ]),
              const SizedBox(height: 20),
              _buildAnimatedSection('Contact Information', [
                buildProfileRow('Father Name', teacherData?['fs_name']??''),
                buildProfileRow('Father Contact', teacherData?['fs_phone']??''),
                buildProfileRow('Contact Number', teacherData?['phone']??''),
                buildProfileRow('Email', teacherData?['email']??''),
                buildProfileRow('Address', teacherData?['permanent_address']??''),
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
            style:  TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors2.textblack),
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
              style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors2.textblack),
            ),
            const SizedBox(width: 10),  // Add some space between label and value
            Expanded(
              child: Text(
                value.isNotEmpty ? value : 'N/A',
                overflow: TextOverflow.visible,
                style:  TextStyle(color: AppColors2.textblack),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(
      child: CupertinoActivityIndicator(radius: 20),
    );
  }
}

