import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../NewUserBottombarPage/new_user_bottombar_page.dart';
import '../../TecaherUi/UI/bottom_navigation.dart';
import '/constants.dart';
import '../../strings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'login_student.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
  ));
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  List<Map<String, dynamic>> loginStudent = [];
  List<Map<String, dynamic>> loginHistory = [];
  List<Map<String, dynamic>> studentList = [];

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
    _loadSavedCredentials();
  }

  // Load saved email and password from SharedPreferences
  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('saved_email');
    String? savedPassword = prefs.getString('saved_password');
    bool? rememberMe = prefs.getBool('remember_me');

    if (savedEmail != null && savedPassword != null && rememberMe == true) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _loadLoginHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('loginHistory');
    if (data != null) {
      setState(() {
        studentList = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text);
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> tryLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Try Login1
      bool login1Success = await _login1();
      if (login1Success) return;

      // Step 2: Try Login2
      bool login2Success = await _login2();
      if (login2Success) return;

      // Step 3: Try Login3
      bool login3Success = await _login3();
      if (login3Success) return;

      // If all login attempts fail
      _showError2(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _login1() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();
    print('Device id: $deviceToken');

    try {
      final url = Uri.parse(ApiRoutes.loginNewUser);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': _emailController.text,
          'password': _passwordController.text,
          'fcm': deviceToken ?? '',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          if (jsonResponse['students'] != null &&
              jsonResponse['students'].isNotEmpty &&
              jsonResponse['students'][0]['token'] != null) {
            await prefs.setString('newusertoken', jsonResponse['students'][0]['token']);
            // Save the student_id of the logged-in user
            await prefs.setString('selected_student_id', jsonResponse['students'][0]['student_id'].toString());
          }

          await _saveCredentials();
          await prefs.setString('studentList', jsonEncode(jsonResponse['students']));

          setState(() {
            loginStudent = List<Map<String, dynamic>>.from(jsonResponse['students']);
          });

          loginHistory = await _getStoredLoginList();
          for (var student in loginStudent) {
            bool exists = loginHistory.any((s) => s['student_id'] == student['student_id']);
            if (!exists) loginHistory.insert(0, student);
          }
          await _saveLoginList(loginHistory);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NewUserBottombarPage()),
            );
          }

          return true; // Success
        }
      }
      return false; // Fail
    } catch (e) {
      // _handleError(e, AppStrings.unexpectedError);
      return false; // Fail
    }
  }

  Future<bool> _login2() async {
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
        final jsonResponse = response.data;
        if (jsonResponse['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('studentList', jsonEncode(jsonResponse['students']));
          // Save the student_id of the logged-in user
          if (jsonResponse['students'] != null &&
              jsonResponse['students'].isNotEmpty &&
              jsonResponse['students'][0]['student_id'] != null) {
            await prefs.setString('selected_student_id', jsonResponse['students'][0]['student_id'].toString());
          }
          await _saveCredentials();

          setState(() {
            loginStudent = List<Map<String, dynamic>>.from(jsonResponse['students']);
          });

          loginHistory = await _getStoredLoginList();
          for (var student in loginStudent) {
            bool exists = loginHistory.any((s) => s['adm_no'] == student['adm_no']);
            if (!exists) loginHistory.insert(0, student);
          }
          await _saveLoginList(loginHistory);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginStudentPage()),
            );
          }

          return true; // Success
        }
      }
      return false; // Fail
    } catch (e) {
      // _handleError(e, AppStrings.unexpectedError);
      return false; // Fail
    }
  }

  Future<bool> _login3() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();

    try {
      final url = Uri.parse(ApiRoutes.teacherlogin);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': _emailController.text,
          'password': _passwordController.text,
          'fcm': deviceToken ?? '',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (jsonResponse['students'] != null &&
            jsonResponse['students'].isNotEmpty &&
            jsonResponse['students'][0]['token'] != null) {
          await prefs.setString('teachertoken', jsonResponse['students'][0]['token']);
          // Save the student_id of the logged-in user
          await prefs.setString('selected_student_id', jsonResponse['students'][0]['student_id'].toString());
        }

        await _saveCredentials();
        await prefs.setString('studentList', jsonEncode(jsonResponse['students']));

        setState(() {
          loginStudent = List<Map<String, dynamic>>.from(jsonResponse['students']);
        });

        loginHistory = await _getStoredLoginList();
        for (var student in loginStudent) {
          bool exists = loginHistory.any((s) => s['student_id'] == student['student_id']);
          if (!exists) loginHistory.insert(0, student);
        }
        await _saveLoginList(loginHistory);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TeacherBottomNavBarScreen(initialIndex: 0)),
          );
        }

        return true; // Success
      }
      return false; // Fail
    } catch (e) {
      // _handleError(e, AppStrings.unexpectedError);
      return false; // Fail
    }
  }

  void _showError2(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Text(
                "Error",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "Invalid username or password. Please try again.",
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }



  Future<void> _saveLoginList(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loginHistory', jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> _getStoredLoginList() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('loginHistory');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  void _handleError(dynamic e, String fallbackMessage) {
    print('${AppStrings.generalErrorDebug}$e');
    String errorMessage = fallbackMessage;
    if (e is DioException && e.response != null) {
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      } else if (e.response?.data is String) {
        errorMessage = e.response?.data;
      }
    }
    _showErrorDialog(errorMessage);
  }

  void _showErrorDialog(String message) {
    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
        Center(
        child: Padding(
        padding: EdgeInsets.all(15.sp),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: EdgeInsets.all(12.sp),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: 90.sp,
                      width: 90.sp,
                      child: Image.asset(AppAssets.cjmlogo),
                    ),
                    Text(
                      'Convent of Jesus & Mary'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30.sp),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      CupertinoIcons.mail_solid,
                      color: Colors.black,
                    ),
                    hintText: 'Enter User Id, or Adm. no',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blueAccent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
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
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your User Id or Adm. no';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      CupertinoIcons.padlock_solid,
                      color: Colors.black,
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
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blueAccent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
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
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppStrings.passwordRequired;
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters long';
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.secondary,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    Text(
                      'Remember Me',
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  Center(child: CircularProgressIndicator())
                else
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.sp),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : tryLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 45.sp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 10.sp),
              ],
            ),
          ),
        ),
      ),
        )
      ],
    ),
    ),
    );
  }
}