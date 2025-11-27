import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../strings.dart';
import '/UI/bottom_navigation.dart';
import '/constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio(); // Initialize Dio
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();
    print('Device id: $deviceToken');
    if (!_formKey.currentState!.validate()) return;

    print('${AppStrings.apiLoginUrl}${ApiRoutes.login}'); // Debug: Print the API URL
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        ApiRoutes.login,
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
          'fcm': deviceToken,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print(' Device token : - $deviceToken');

      print('${AppStrings.responseStatusDebug}${response.statusCode}'); // Debug: Print status code
      print('${AppStrings.responseDataDebug}${response.data}'); // Debug: Print the response data

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          // Save token in SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', responseData['token']);
          print('${AppStrings.tokenSaved}${responseData['token']}'); // Debug: Print the saved token

          // Retrieve the token
          String? token = prefs.getString('token');
          print('${AppStrings.tokenRetrieved}$token'); // Debug: Print retrieved token

          // Navigate to the BottomNavBarScreen with the token
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BottomNavBarScreen(initialIndex: 0,),
            ),
          );
        } else {
          print('${AppStrings.loginFailedDebug}${responseData['message']}'); // Debug: Print failure message
          _showErrorDialog(responseData['message']);
        }
      } else {
        print('${AppStrings.loginFailedMessage} ${response.statusCode}'); // Debug: Unexpected status code
        _showErrorDialog(AppStrings.loginFailedMessage);
      }
    } on DioException catch (e) {
      print('${AppStrings.dioExceptionDebug}${e.message}'); // Debug: Print DioException message

      String errorMessage = AppStrings.unexpectedError;
      if (e.response != null) {
        print('${AppStrings.errorResponseDebug}${e.response?.data}'); // Debug: Print error response data

        if (e.response?.data is Map<String, dynamic>) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else if (e.response?.data is String) {
          errorMessage = e.response?.data;
        }
      } else {
        errorMessage = e.message ?? 'Unable to connect to the server.';
      }

      _showErrorDialog(errorMessage);
    } catch (e) {
      print('${AppStrings.generalErrorDebug}$e'); // Catch any other errors
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
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [

              const SizedBox(height: 20),
              Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Container(
                            height: 110.sp,
                            width: 180.sp,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10.sp)
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  height: 90.sp,
                                  width: 90.sp,
                                  child: Image.asset(
                                    AppAssets.cjmlogo,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            AppStrings.studentLogin,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(CupertinoIcons.mail_solid),
                          hintText: AppStrings.email,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppStrings.invalidEmail;
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return AppStrings.invalidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(CupertinoIcons.lock_shield_fill),
                          hintText: AppStrings.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? CupertinoIcons.eye_slash_fill
                                  : CupertinoIcons.eye_solid,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppStrings.passwordRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CupertinoSwitch (
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value!;
                              });
                            },
                          ),
                          const Text(AppStrings.rememberMe),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_isLoading) const CircularProgressIndicator() else SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {

                            _login();
                            // var token = "123"; // Define the token
                            // Navigator.pushReplacement(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => BottomNavBarScreen(token: token), // Pass the token directly
                            //   ),
                            // );
                          },
                          child:  Text(
                            AppStrings.login,
                            style: TextStyle(fontSize: 16, color: AppColors.textblack),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

               Column(
                children: [

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Provider by AVI-SUN',
                      style: GoogleFonts.montserrat(
                        textStyle: Theme.of(context).textTheme.displayLarge,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        color: AppColors.textblack,
                      ),
                    ),
                  )

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
