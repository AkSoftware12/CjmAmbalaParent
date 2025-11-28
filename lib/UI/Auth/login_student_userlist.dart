import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../NewUserBottombarPage/new_user_bottombar_page.dart';
import '../../TecaherUi/UI/bottom_navigation.dart';
import '/UI/bottom_navigation.dart';
import '/constants.dart';
import '../../strings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'login_screen.dart';

class LoginUserLIst extends StatefulWidget {
  const LoginUserLIst({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginUserLIst> {
  final Dio _dio = Dio(); // Initialize Dio
  bool _isLoading = false;
  List<Map<String, dynamic>> studentList = [];
  String? selectedOption;
  String? selectedAdmNo; // adm_no alag store karne ke liye
  String? staffPass;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
    _loadSelectedStudent(); // Load the previously selected student

    print('SelectedOption Int$selectedOption');
    print('SelectedAdm Int$selectedAdmNo');
    print('SelectedStaff Int$staffPass');
  }

  // Load previously selected student_id from SharedPreferences
  Future<void> _loadSelectedStudent() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedStudentId = prefs.getString('selected_student_id');

    if (savedStudentId != null && studentList.isNotEmpty) {
      // Find the student in the studentList with the matching student_id
      var selectedStudent = studentList.firstWhere(
        (student) => student['student_id'].toString() == savedStudentId,
        orElse: () => {}, // Return empty map if not found
      );

      if (selectedStudent.isNotEmpty) {
        setState(() {
          selectedOption = savedStudentId;
          selectedAdmNo = selectedStudent['adm_no']?.toString();
          staffPass = selectedStudent['password']?.toString();
        });
      }
    }
  }

  Future<void> _login() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();
    print('Device id Old: $deviceToken');

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        ApiRoutes.loginstudent,
        data: {'student_id': selectedOption, 'fcm': deviceToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('Device token: $deviceToken');
      print('${AppStrings.responseStatusDebug}${response.statusCode}');
      print('${AppStrings.responseDataDebug}${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.remove('teachertoken');
          await prefs.remove('newusertoken');
          await prefs.setString('token', responseData['token']);
          await prefs.setString(
            'selected_student_id',
            selectedOption!,
          ); // Save selected student_id

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BottomNavBarScreen(initialIndex: 0),
            ),
          );
        } else {
          print('${AppStrings.loginFailedDebug}${responseData['message']}');
          _showErrorDialog(responseData['message']);
        }
      } else {
        print('${AppStrings.loginFailedMessage} ${response.statusCode}');
        _showErrorDialog(AppStrings.loginFailedMessage);
      }
    } on DioException catch (e) {
      print('${AppStrings.dioExceptionDebug}${e.message}');
      String errorMessage = AppStrings.unexpectedError;
      if (e.response != null) {
        print('${AppStrings.errorResponseDebug}${e.response?.data}');
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
      print('${AppStrings.generalErrorDebug}$e');
      _showErrorDialog(AppStrings.unexpectedError);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginNewUser() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();
    print('Device id New: $deviceToken');

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        ApiRoutes.loginstudentNewUser,
        data: {'student_id': selectedOption, 'fcm': deviceToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('Device token: $deviceToken');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.remove('teachertoken');
          await prefs.remove('token');
          await prefs.setString('newusertoken', responseData['token']);
          await prefs.setString(
            'selected_student_id',
            selectedOption!,
          ); // Save selected student_id

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const NewUserBottombarPage(),
            ),
          );
        } else {
          print('${AppStrings.loginFailedDebug}${responseData['message']}');
          _showErrorDialog(responseData['message']);
        }
      } else {
        print('${AppStrings.loginFailedMessage} ${response.statusCode}');
        _showErrorDialog(AppStrings.loginFailedMessage);
      }
    } on DioException catch (e) {
      print('${AppStrings.dioExceptionDebug}${e.message}');
      String errorMessage = AppStrings.unexpectedError;
      if (e.response != null) {
        print('${AppStrings.errorResponseDebug}${e.response?.data}');
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
      print('${AppStrings.generalErrorDebug}$e');
      _showErrorDialog(AppStrings.unexpectedError);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginTeacher() async {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    String? deviceToken = await _firebaseMessaging.getToken();
    print('Device id: $deviceToken');

    if (mounted) setState(() => _isLoading = true);

    try {
      final url = Uri.parse(ApiRoutes.teacherlogin);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': selectedOption,
          'password': staffPass,
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
            await prefs.remove('newusertoken');
            await prefs.remove('token');
            await prefs.setString(
              'teachertoken',
              jsonResponse['students'][0]['token'],
            );
            await prefs.setString(
              'selected_student_id',
              selectedOption!,
            ); // Save selected student_id
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TeacherBottomNavBarScreen(initialIndex: 0),
              ),
            );
          }
        } else {
          _showErrorDialog(jsonResponse['message'] ?? 'Login failed');
        }
      } else {
        _showErrorDialog('Login failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog(AppStrings.unexpectedError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _saveSelectedStudent(String studentId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_student_id', studentId);
  }

  // Future<void> _loadLoginHistory() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   String? data = prefs.getString('loginHistory');
  //   if (data != null) {
  //     setState(() {
  //       studentList = List<Map<String, dynamic>>.from(jsonDecode(data));
  //     });
  //     // Load selected student after loading login history
  //     _loadSelectedStudent();
  //   }
  // }

  Future<void> _loadLoginHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('loginHistory');
    if (data != null) {
      List<Map<String, dynamic>> loadedList = List<Map<String, dynamic>>.from(
        jsonDecode(data),
      );
      setState(() {
        studentList = loadedList;
      });

      // Ab list aagayi, abhi selected student load karo
      String? savedStudentId = prefs.getString('selected_student_id');
      if (savedStudentId != null) {
        var selectedStudent = loadedList.firstWhere(
          (student) => student['student_id'].toString() == savedStudentId,
          orElse: () => {},
        );

        if (selectedStudent.isNotEmpty) {
          setState(() {
            selectedOption = savedStudentId;
            selectedAdmNo = selectedStudent['adm_no']?.toString();
            staffPass = selectedStudent['password']?.toString();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: EdgeInsets.all(10.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Section
                  Container(
                    height: 90.sp,
                    width: 180.sp,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.sp),
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
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.error);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Select Student Text
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Select Student ",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '(${studentList.length.toString()})',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Constrain ListView height
                  SizedBox(
                    height: 250.sp,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: studentList.length,
                      itemBuilder: (context, index) {
                        final student = studentList[index];
                        if (student == null ||
                            student['name'] == null ||
                            student['student_id'] == null ||
                            student['adm_no'] == null) {
                          return const ListTile(
                            title: Text('Invalid Student Data'),
                          );
                        }
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: RadioListTile<String>(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['name'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      student['student_id'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: (student['adm_no'] == 'null')
                                    ? Text(
                                        '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Text(
                                        student['adm_no'].toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                value: student['student_id'].toString(),
                                groupValue: selectedOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedOption = value;
                                    selectedAdmNo = student['adm_no']
                                        .toString();
                                    staffPass = student['password'].toString();
                                  });
                                  _saveSelectedStudent(value!);
                                },
                                activeColor: AppColors.secondary,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                elevation: 5,
                                margin: EdgeInsets.zero,
                                color: Colors.white,
                                child: Padding(
                                  padding: EdgeInsets.all(3.sp),
                                  child: student['password'] != null
                                      ? Text(
                                          'Teacher',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 8.sp,
                                          ),
                                        )
                                      : Text(
                                          'Student',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 8.sp,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 50.sp),
                  // Loading Indicator or Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: EdgeInsets.only(left: 18.sp, right: 18.sp),
                          child: CustomLoginButton(
                            onPressed: () {
                              if (selectedOption == null) {
                                _showErrorDialog(
                                  "Please select a student first",
                                );
                                return;
                              }

                              if (selectedAdmNo == 'null' ||
                                  selectedAdmNo == null) {
                                if (staffPass == 'null' || staffPass == null) {
                                  _loginNewUser();
                                } else {
                                  _loginTeacher();
                                }
                              } else {
                                _login();
                              }

                              print("Selected Option: $selectedOption");
                            },

                            title: 'Go',
                          ),
                        ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Provider by AVI-SUN',
                style: GoogleFonts.montserrat(
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
      onTapUp: (_) async {
        setState(() => isPressed = true);

        // Let the ripple animation happen first (optional)
        await Future.delayed(Duration(milliseconds: 100));

        if (mounted) {
          setState(() => isPressed = false);
        }

        // Navigate or perform login after animation is done
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
                ? [AppColors.secondary, AppColors.primary]
                : [AppColors.secondary, AppColors.primary],
          ),
          boxShadow: isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
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
