import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../Auth/login_student.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int id;
  const ChangePasswordScreen({super.key, required this.id});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  List<Map<String, dynamic>> loginStudent = [];

  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  int _newPasswordLength = 0;
  int _confirmPasswordLength = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static final Color _red = AppColors.primary;
  static const Color _redLight = Color(0xFFEF5350);
  static Color _redDark = AppColors.primary;
  static const Color _bg = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.post(
        ApiRoutes.passwordChange,
        data: {
          'id': widget.id,
          'password': _confirmPasswordController.text,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final jsonResponse = response.data;

        // ✅ 'status' check karo, 'success' nahi
        if (jsonResponse['status'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();

          // ✅ 'student' single object hai, array nahi
          final student = jsonResponse['student'] as Map<String, dynamic>;

          // Student list mein wrap karke store karo (purana format maintain karne ke liye)
          final List<Map<String, dynamic>> students = [student];
          await prefs.setString('studentList', jsonEncode(students));

          if (student['student_id'] != null) {
            await prefs.setString(
              'selected_student_id',
              student['student_id'].toString(),
            );
          }

          List<Map<String, dynamic>> loginHistory = await _getStoredLoginList();
          bool exists = loginHistory.any((s) => s['adm_no'] == student['adm_no']);
          if (!exists) loginHistory.insert(0, student);
          await _saveLoginList(loginHistory);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginStudentPage()),
          );
        } else {
          final msg = jsonResponse['message'] ?? 'Something went wrong';
          _showErrorSnackBar(msg);
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.response?.data?['message'] ?? 'Something went wrong';
      _showErrorSnackBar(msg);
    }
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
  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Icon Banner
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_redLight, _redDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Set New Password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _redDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Password must contain numbers only',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── New Password ──────────────────────────────────
                  _buildLabel('New Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_newPasswordVisible,
                    keyboardType: TextInputType.number,
                    // ✅ Sirf digits allow
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) =>
                        setState(() => _newPasswordLength = val.length),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter new password';
                      }
                      if (val.length < 5) {
                        return 'Password must be at least 6 digits';
                      }
                      return null;
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: _passwordDecoration(
                      hint: 'Enter new password (numbers only)',
                      isVisible: _newPasswordVisible,
                      onToggle: () => setState(
                              () => _newPasswordVisible = !_newPasswordVisible),
                    ),
                  ),
                  if (_newPasswordLength < 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 13,
                              color: _newPasswordLength == 0
                                  ? Colors.grey.shade400
                                  : _red),
                          const SizedBox(width: 5),
                          Text(
                            '${5 - _newPasswordLength} more digit${(5 - _newPasswordLength) == 1 ? '' : 's'} needed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _newPasswordLength == 0
                                  ? Colors.grey.shade400
                                  : _red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(5, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 3),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < _newPasswordLength
                                      ? _red
                                      : Colors.grey.shade300,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 22),

                  // ── Confirm Password ──────────────────────────────
                  _buildLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_confirmPasswordVisible,
                    keyboardType: TextInputType.number,
                    // ✅ Sirf digits allow
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) =>
                        setState(() => _confirmPasswordLength = val.length),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (val != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: _passwordDecoration(
                      hint: 'Re-enter new password (numbers only)',
                      isVisible: _confirmPasswordVisible,
                      onToggle: () => setState(() =>
                      _confirmPasswordVisible = !_confirmPasswordVisible),
                    ),
                  ),
                  if (_confirmPasswordLength < 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 13,
                              color: _confirmPasswordLength == 0
                                  ? Colors.grey.shade400
                                  : _red),
                          const SizedBox(width: 5),
                          Text(
                            '${5 - _confirmPasswordLength} more digit${(5 - _confirmPasswordLength) == 1 ? '' : 's'} needed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _confirmPasswordLength == 0
                                  ? Colors.grey.shade400
                                  : _red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(5, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 3),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < _confirmPasswordLength
                                      ? _red
                                      : Colors.grey.shade300,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                  if (_confirmPasswordLength >= 5)
                    Builder(builder: (_) {
                      final isMatch = _newPasswordController.text ==
                          _confirmPasswordController.text;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMatch
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isMatch
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFEF9A9A),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isMatch
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 16,
                              color: isMatch
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              isMatch
                                  ? 'Passwords match ✓'
                                  : 'Passwords do not match',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isMatch
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Password Tips
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_rounded,
                                color: _red, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Password Tips',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _red,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTip('Only 5 digits numeric'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Change Password Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _red.withOpacity(0.6),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D2D2D),
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(Icons.lock_outline_rounded, color: _red, size: 22),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isVisible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            key: ValueKey(isVisible),
            color: isVisible ? _red : Colors.grey.shade400,
            size: 22,
          ),
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _red, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle:
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: _red.withOpacity(0.7), size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}