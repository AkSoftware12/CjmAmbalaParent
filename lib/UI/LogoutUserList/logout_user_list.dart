import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/login_screen.dart';
import '/constants.dart';

class LogoutUserList extends StatefulWidget {
  const LogoutUserList({super.key});

  @override
  State<LogoutUserList> createState() => _LogoutUserListState();
}

class _LogoutUserListState extends State<LogoutUserList> {
  bool _isLoading = false;

  List<Map<String, dynamic>> _studentList = [];
  Map<String, dynamic>? _selectedUser; // ✅ only selected user object
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _loadSelectedUserOnly();
  }

  Future<void> _loadSelectedUserOnly() async {
    final prefs = await SharedPreferences.getInstance();

    final savedId = prefs.getString('selected_student_id');
    final history = prefs.getString('loginHistory');

    if (history == null || history.trim().isEmpty || savedId == null) {
      if (mounted) {
        setState(() {
          _studentList = [];
          _selectedUser = null;
          _selectedStudentId = null;
        });
      }
      return;
    }

    final loadedList =
    List<Map<String, dynamic>>.from(jsonDecode(history) as List<dynamic>);

    Map<String, dynamic>? found;
    for (final e in loadedList) {
      if (e['student_id']?.toString() == savedId) {
        found = e;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _studentList = loadedList;
        _selectedStudentId = savedId;
        _selectedUser = found; // ✅ only this user will show
      });
    }
  }

  Future<void> _logoutSelectedUser() async {
    if (_selectedStudentId == null || _selectedUser == null) {
      _showErrorDialog("No selected user found.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ 1) Clear tokens
      await prefs.remove('token');
      await prefs.remove('newusertoken');
      await prefs.remove('teachertoken');

      // ✅ 2) Remove selected user from loginHistory
      final updatedList = List<Map<String, dynamic>>.from(_studentList);
      updatedList.removeWhere(
            (e) => e['student_id']?.toString() == _selectedStudentId,
      );

      await prefs.setString('loginHistory', jsonEncode(updatedList));

      // ✅ 3) Clear selected_student_id
      await prefs.remove('selected_student_id');

      if (!mounted) return;

      setState(() {
        _studentList = updatedList;
        _selectedUser = null;
        _selectedStudentId = null;
      });

      // ✅ 4) Navigate after logout
      // Yaha aap apna Login/Select screen open karwa do:
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      // OR if you use named routes:
      // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    } catch (e) {
      if (mounted) _showErrorDialog("Logout failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logoutSelectedUser();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedUser;

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
                  // Logo
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
                        child: Image.asset(
                          AppAssets.cjmlogo,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Selected User",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Only selected user show
                  if (selected == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "No user selected. Please login again.",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (selected['name'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (selected['student_id'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: (selected['adm_no'] == null ||
                                selected['adm_no'].toString() == 'null')
                                ? const SizedBox.shrink()
                                : Text(
                              selected['adm_no'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.verified,
                              color: AppColors.secondary,
                            ),
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
                              child: (selected['password'] != null &&
                                  selected['password'].toString() != 'null')
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
                    ),

                  SizedBox(height: 30.sp),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                    padding: EdgeInsets.only(left: 18.sp, right: 18.sp),
                    child: CustomLoginButton(
                      title: 'Logout',
                      onPressed: () {
                        if (selected == null) {
                          _showErrorDialog(
                            "No selected user. Please login again.",
                          );
                          return;
                        }
                        _logoutSelectedUser();

                        // _showLogoutDialog();
                      },
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
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
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
  State<CustomLoginButton> createState() => _CustomLoginButtonState();
}

class _CustomLoginButtonState extends State<CustomLoginButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapCancel: () => setState(() => isPressed = false),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) setState(() => isPressed = false);
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [AppColors.secondary, AppColors.primary],
          ),
          boxShadow: isPressed
              ? []
              : [
            BoxShadow(
              color: Colors.blue.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.title,
            style: const TextStyle(
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