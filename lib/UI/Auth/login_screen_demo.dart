import 'dart:convert';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/UI/bottom_navigation.dart';
import '/constants.dart';
import '../../strings.dart';

import 'login_student.dart';

class LoginPageDemo extends StatefulWidget {
  const LoginPageDemo({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPageDemo> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio(); // Initialize Dio
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;

  List loginStudent = []; // Declare a list to hold API data

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        ApiRoutes.login,
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = response.data; // FIX: No need to decode

        if (jsonResponse['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'studentList',
            jsonEncode(jsonResponse['students']),
          );
          setState(() {
            loginStudent =
                jsonResponse['students']; // Update state with fetched data
            _isLoading = false;
            print('Login Student: $loginStudent');
          });

          // Navigate to the bottom navigation screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginStudentPage()),
          );
        } else {
          print('${AppStrings.loginFailedDebug}${jsonResponse['message']}');
          _showErrorDialog(jsonResponse['message']);
        }
      } else {
        print('${AppStrings.loginFailedMessage} ${response.statusCode}');
        _showErrorDialog(AppStrings.loginFailedMessage);
      }
    } on DioException catch (e) {
      String errorMessage = AppStrings.unexpectedError;
      if (e.response != null && e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      } else if (e.response?.data is String) {
        errorMessage = e.response?.data;
      }

      _showErrorDialog(errorMessage);
    } catch (e) {
      print('${AppStrings.generalErrorDebug}$e');
      _showErrorDialog(AppStrings.unexpectedError);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.loginFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 130.sp,
                width: double.infinity,
                child: Image.asset(
                  'assets/login_top.png',
                  fit: BoxFit.fill,
                  color: HexColor('#3a1e0d'),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 130.sp,
                child: Image.asset(
                  'assets/login_bottom.png',
                  fit: BoxFit.fill,
                  color: HexColor('#3a1e0d'),
                ),
              ),
            ],
          ),
          Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    padding: EdgeInsets.all(12.sp),
                    // decoration: BoxDecoration(
                    //   color: Colors.white,
                    //   borderRadius: BorderRadius.circular(10),
                    //   boxShadow: [
                    //     BoxShadow(
                    //       color: Colors.black26,
                    //       blurRadius: 10,
                    //       offset: const Offset(0, 4),
                    //     ),
                    //   ],
                    // ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        // mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [

                              // const SizedBox(height: 5),
                              Text(
                                'A One Recovery'.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.sp),

                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                CupertinoIcons.person,
                                color:
                                    Colors.black, // आइकन का रंग बेहतर किया गया
                              ),
                              hintText: 'Name',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // बॉर्डर को अधिक स्मूथ किया
                                borderSide: BorderSide(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ), // अधिक स्पष्ट फोकस बॉर्डर
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ), // बेहतर padding
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.invalidEmail;
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(value)) {
                                return AppStrings.invalidEmail;
                              }
                              return null;
                            },

                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                CupertinoIcons.mail_solid,
                                color:
                                    Colors.black, // आइकन का रंग बेहतर किया गया
                              ),
                              hintText: AppStrings.email,
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // बॉर्डर को अधिक स्मूथ किया
                                borderSide: BorderSide(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ), // अधिक स्पष्ट फोकस बॉर्डर
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ), // बेहतर padding
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.invalidEmail;
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(value)) {
                                return AppStrings.invalidEmail;
                              }
                              return null;
                            },

                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                CupertinoIcons.phone,
                                color:
                                    Colors.black, // आइकन का रंग बेहतर किया गया
                              ),
                              hintText: 'Phone',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // बॉर्डर को अधिक स्मूथ किया
                                borderSide: BorderSide(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ), // अधिक स्पष्ट फोकस बॉर्डर
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ), // बेहतर padding
                            ),

                            // validator: (value) {
                            //   if (value == null || value.isEmpty) {
                            //     return AppStrings.invalidEmail;
                            //   }
                            //   if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            //     return AppStrings.invalidEmail;
                            //   }
                            //   return null;
                            // },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Email Input
                          // TextFormField(
                          //   controller: _emailController,
                          //   decoration: InputDecoration(
                          //     prefixIcon: Container(
                          //       margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), // Proper spacing
                          //       decoration: BoxDecoration(
                          //         color: Colors.blue.shade100, // Soft blue shade background
                          //         shape: BoxShape.circle, // Circular background
                          //       ),
                          //       child: Padding(
                          //         padding: const EdgeInsets.all(0), // Proper spacing inside icon
                          //         child: const Icon(
                          //           CupertinoIcons.mail_solid,
                          //           color: Colors.blue, // Matching theme color
                          //         ),
                          //       ),
                          //     ),
                          //     hintText: AppStrings.email,
                          //     hintStyle: TextStyle(color: Colors.grey.shade600), // Subtle hint text color
                          //     filled: true,
                          //     fillColor: Colors.grey.shade100, // Light background
                          //     border: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(12), // Smooth rounded edges
                          //       borderSide: BorderSide.none, // No default border
                          //     ),
                          //     focusedBorder: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(12),
                          //       borderSide: BorderSide(color: Colors.blue.shade300, width: 2), // Highlighted border
                          //     ),
                          //     enabledBorder: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(12),
                          //       borderSide: BorderSide(color: Colors.grey.shade300), // Subtle border
                          //     ),
                          //   ),
                          //   validator: (value) {
                          //     if (value == null || value.isEmpty) {
                          //       return AppStrings.invalidEmail;
                          //     }
                          //     if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          //       return AppStrings.invalidEmail;
                          //     }
                          //     return null;
                          //   },
                          // ),
                          const SizedBox(height: 15),
                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                CupertinoIcons.padlock_solid,
                                color:
                                    Colors.black, // आइकन का रंग बेहतर किया गया
                              ),
                              hintText: AppStrings.password,
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? CupertinoIcons.eye_slash_fill
                                      : CupertinoIcons.eye_solid,
                                  color: Colors
                                      .black, // आँख का आइकन भी स्टाइलिश बनाया गया
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // बॉर्डर को अधिक स्मूथ किया
                                borderSide: BorderSide(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ), // अधिक स्पष्ट फोकस बॉर्डर
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ), // बेहतर padding
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.passwordRequired;
                              }
                              return null;
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                CupertinoIcons.padlock_solid,
                                color:
                                    Colors.black, // आइकन का रंग बेहतर किया गया
                              ),
                              hintText: 'Confirm Password ',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? CupertinoIcons.eye_slash_fill
                                      : CupertinoIcons.eye_solid,
                                  color: Colors
                                      .black, // आँख का आइकन भी स्टाइलिश बनाया गया
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // बॉर्डर को अधिक स्मूथ किया
                                borderSide: BorderSide(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ), // अधिक स्पष्ट फोकस बॉर्डर
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ), // बेहतर padding
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.passwordRequired;
                              }
                              return null;
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.end,
                          //   children: [
                          //     GestureDetector(
                          //       onTap: () {
                          //         // Navigate to the forgot password screen or perform an action
                          //         print("Forgot Password clicked");
                          //       },
                          //       child: Text(
                          //         'Forgot Password?',
                          //         style: TextStyle(color: Colors.redAccent, decoration: TextDecoration.none),
                          //       ),
                          //     )
                          //   ],
                          // ),

                          // Row(
                          //   children: [
                          //
                          //     CupertinoSwitch (
                          //       value: _rememberMe,
                          //       onChanged: (value) {
                          //         setState(() {
                          //           _rememberMe = value!;
                          //         });
                          //       },
                          //     ),
                          //     const Text(AppStrings.rememberMe),
                          //   ],
                          // ),
                          SizedBox(height: 20.sp),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else
                            Padding(
                              padding: EdgeInsets.only(
                                left: 18.sp,
                                right: 18.sp,
                              ),
                              child: CustomLoginButton(
                                onPressed: () {
                                  _login();
                                },
                                title: 'Register'.toUpperCase(),
                              ),
                            ),

                          //   SizedBox(
                          //   width: double.infinity,
                          //   child: ElevatedButton(
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: AppColors.primary,
                          //       padding: const EdgeInsets.symmetric(vertical: 15),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(8),
                          //       ),
                          //     ),
                          //     onPressed: () {
                          //
                          //       _login();
                          //       // var token = "123"; // Define the token
                          //       // Navigator.pushReplacement(
                          //       //   context,
                          //       //   MaterialPageRoute(
                          //       //     builder: (context) => BottomNavBarScreen(token: token), // Pass the token directly
                          //       //   ),
                          //       // );
                          //     },
                          //     child:  Text(
                          //       AppStrings.login,
                          //       style: TextStyle(fontSize: 16, color: AppColors.textwhite),
                          //     ),
                          //   ),
                          // ),
                          // SizedBox(height: 50.sp),
                        ],
                      ),
                    ),
                  ),
                ),

                // Center(
                //   child: SingleChildScrollView(
                //     child: Column(
                //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //       children: [
                //
                //         Container(
                //           width: 350,
                //           padding: const EdgeInsets.all(20),
                //           decoration: BoxDecoration(
                //             color: Colors.white,
                //             borderRadius: BorderRadius.circular(10),
                //             boxShadow: [
                //               BoxShadow(
                //                 color: Colors.black26,
                //                 blurRadius: 10,
                //                 offset: const Offset(0, 4),
                //               ),
                //             ],
                //           ),
                //           child: Form(
                //             key: _formKey,
                //             child: Column(
                //               mainAxisSize: MainAxisSize.min,
                //               children: [
                //                 Column(
                //                   children: [
                //                     Container(
                //                       height: 110.sp,
                //                       width: 180.sp,
                //                       decoration: BoxDecoration(
                //                           color: Colors.grey.shade200,
                //                           borderRadius: BorderRadius.circular(10.sp)
                //                       ),
                //                       child: Padding(
                //                         padding: const EdgeInsets.all(8.0),
                //                         child: ClipRRect(
                //                           borderRadius: BorderRadius.circular(10),
                //                           child: SizedBox(
                //                             height: 90.sp,
                //                             width: 90.sp,
                //                             child: Image.asset(
                //                               AppAssets.cjmlogo,
                //                             ),
                //                           ),
                //                         ),
                //                       ),
                //                     ),
                //                     const SizedBox(height: 5),
                //                     const Text(
                //                       AppStrings.studentLogin,
                //                       style: TextStyle(
                //                         fontSize: 20,
                //                         fontWeight: FontWeight.bold,
                //                       ),
                //                     ),
                //                   ],
                //                 ),
                //                 const SizedBox(height: 20),
                //                 // Email Input
                //                 TextFormField(
                //                   controller: _emailController,
                //                   decoration: InputDecoration(
                //                     prefixIcon: const Icon(CupertinoIcons.mail_solid),
                //                     hintText: AppStrings.email,
                //                     border: OutlineInputBorder(
                //                       borderRadius: BorderRadius.circular(8),
                //                     ),
                //                   ),
                //                   validator: (value) {
                //                     if (value == null || value.isEmpty) {
                //                       return AppStrings.invalidEmail;
                //                     }
                //                     if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                //                       return AppStrings.invalidEmail;
                //                     }
                //                     return null;
                //                   },
                //                 ),
                //                 const SizedBox(height: 15),
                //                 // Password Input
                //                 TextFormField(
                //                   controller: _passwordController,
                //                   obscureText: !_isPasswordVisible,
                //                   decoration: InputDecoration(
                //                     prefixIcon: const Icon(CupertinoIcons.lock_shield_fill),
                //                     hintText: AppStrings.password,
                //                     suffixIcon: IconButton(
                //                       icon: Icon(
                //                         _isPasswordVisible
                //                             ? CupertinoIcons.eye_slash_fill
                //                             : CupertinoIcons.eye_solid,
                //                       ),
                //                       onPressed: () {
                //                         setState(() {
                //                           _isPasswordVisible = !_isPasswordVisible;
                //                         });
                //                       },
                //                     ),
                //                     border: OutlineInputBorder(
                //                       borderRadius: BorderRadius.circular(8),
                //                     ),
                //                   ),
                //                   validator: (value) {
                //                     if (value == null || value.isEmpty) {
                //                       return AppStrings.passwordRequired;
                //                     }
                //                     return null;
                //                   },
                //                 ),
                //                 const SizedBox(height: 10),
                //                 Row(
                //                   children: [
                //                     CupertinoSwitch (
                //                       value: _rememberMe,
                //                       onChanged: (value) {
                //                         setState(() {
                //                           _rememberMe = value!;
                //                         });
                //                       },
                //                     ),
                //                     const Text(AppStrings.rememberMe),
                //                   ],
                //                 ),
                //                 const SizedBox(height: 10),
                //                 if (_isLoading) const CircularProgressIndicator() else SizedBox(
                //                   width: double.infinity,
                //                   child: ElevatedButton(
                //                     style: ElevatedButton.styleFrom(
                //                       backgroundColor: AppColors.primary,
                //                       padding: const EdgeInsets.symmetric(vertical: 15),
                //                       shape: RoundedRectangleBorder(
                //                         borderRadius: BorderRadius.circular(8),
                //                       ),
                //                     ),
                //                     onPressed: () {
                //
                //                       _login();
                //                       // var token = "123"; // Define the token
                //                       // Navigator.pushReplacement(
                //                       //   context,
                //                       //   MaterialPageRoute(
                //                       //     builder: (context) => BottomNavBarScreen(token: token), // Pass the token directly
                //                       //   ),
                //                       // );
                //                     },
                //                     child:  Text(
                //                       AppStrings.login,
                //                       style: TextStyle(fontSize: 16, color: AppColors.textwhite),
                //                     ),
                //                   ),
                //                 ),
                //               ],
                //             ),
                //           ),
                //         ),
                //
                //         // Column(
                //         //   children: [
                //         //
                //         //     Padding(
                //         //       padding:  EdgeInsets.only(top: 8.0),
                //         //       child: Row(
                //         //         mainAxisAlignment: MainAxisAlignment.center,
                //         //         children: [
                //         //           Padding(
                //         //             padding: const EdgeInsets.all(0.0),
                //         //             child: Text('Provider by AVI-SUN',
                //         //               style: GoogleFonts.montserrat(
                //         //                 textStyle: Theme.of(context).textTheme.displayLarge,
                //         //                 fontSize: 12.sp,
                //         //                 fontWeight: FontWeight.w600,
                //         //                 fontStyle: FontStyle.normal,
                //         //                 color: Colors.white,
                //         //               ),
                //         //             ),
                //         //           ),
                //         //         ],
                //         //       ),
                //         //     )
                //         //
                //         //   ],
                //         // ),
                //
                //
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomLoginButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String title;
  const CustomLoginButton({
    super.key,
    required this.onPressed,
    required this.title,
  });

  @override
  _CustomLoginButtonState createState() => _CustomLoginButtonState();
}

class _CustomLoginButtonState extends State<CustomLoginButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) {
        Future.delayed(Duration(milliseconds: 100), () {
          setState(() => isPressed = false);
        });
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: isPressed
                ? [HexColor('#3a1e0d'), HexColor('#3a1e0d')]
                : [HexColor('#3a1e0d'), HexColor('#3a1e0d')],
          ),
          boxShadow: isPressed
              ? []
              : [
                  BoxShadow(
                    color: HexColor('#3a1e0d').withOpacity(0.5),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            '${widget.title}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Usage Example:
// CustomLoginButton(onPressed: () {
//   print("Login Clicked!");
// });
