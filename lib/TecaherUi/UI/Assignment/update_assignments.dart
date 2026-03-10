import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../constants.dart';

class AssignmentUpdateScreen extends StatefulWidget {
  final int id;
  final String startDate;
  final String title;
  final String descripation;
  final String marks;
  final String endDate;
  final VoidCallback onReturn;

  const AssignmentUpdateScreen({
    super.key,
    required this.onReturn,
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.descripation,
    required this.marks,
  });

  @override
  _AssignmentUploadScreenState createState() => _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState extends State<AssignmentUpdateScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  File? selectedFile;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController totalMarksController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ─── Theme ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFB71C1C);
  static const Color _primaryLight = Color(0xFFE53935);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _cardBg = Colors.white;
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    titleController.text = widget.title;
    descriptionController.text = widget.descripation;
    totalMarksController.text = widget.marks;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    totalMarksController.dispose();
    super.dispose();
  }

  // ─── File Picker ─────────────────────────────────────────────────────────
  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt', 'xls', 'csv'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => selectedFile = File(result.files.single.path!));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File picker error. Please try again.")),
      );
    }
  }

  // ─── API ─────────────────────────────────────────────────────────────────
  Future<void> uploadAssignmentApi() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      String apiUrl =
          '${ApiRoutes.uploadTeacherAssignment}/${ widget.id}';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      request.fields['title'] = titleController.text;
      request.fields['description'] = descriptionController.text;
      request.fields['start_date'] =
      widget.startDate.toString().split(' ')[0];
      request.fields['end_date'] = widget.endDate.toString().split(' ')[0];
      request.fields['status'] = '1';

      if (selectedFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'attach',
          selectedFile!.path,
          filename: selectedFile!.path.split('/').last,
        ));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        widget.onReturn();
        Fluttertoast.showToast(
          msg: "Assignment updated successfully!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 14.0,
        );
        Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed: ${jsonResponse['message']}"),
          backgroundColor: _primary,
        ));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Please try again.")),
      );
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  String _fileIconEmoji(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return '📄';
      case 'jpg':
      case 'png':
        return '🖼️';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'csv':
        return '📊';
      default:
        return '📎';
    }
  }

  Color _fileColor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'jpg':
      case 'png':
        return const Color(0xFF1E88E5);
      case 'doc':
      case 'docx':
        return const Color(0xFF1565C0);
      case 'xls':
      case 'csv':
        return const Color(0xFF2E7D32);
      default:
        return _textGrey;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("Assignment Details"),
                SizedBox(height: 12.h),
                _buildInputCard(
                  child: Column(
                    children: [
                      _buildTextField(
                        label: "Title",
                        controller: titleController,
                        icon: Icons.title_rounded,
                      ),
                      _divider(),
                      _buildTextField(
                        label: "Description",
                        controller: descriptionController,
                        icon: Icons.notes_rounded,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                _sectionLabel("Attachment"),
                SizedBox(height: 12.h),
                _buildFileSection(),
                SizedBox(height: 32.h),
                _buildSubmitButton(),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: true,
      title: Text(
        "Update Assignment",
        style: GoogleFonts.poppins(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      // leading: GestureDetector(
      //   onTap: () => Navigator.pop(context),
      //   child: Container(
      //     margin: EdgeInsets.all(10.w),
      //     decoration: BoxDecoration(
      //       color: Colors.white.withOpacity(0.15),
      //       borderRadius: BorderRadius.circular(8.r),
      //     ),
      //     child: const Icon(Icons.arrow_back_ios_new_rounded,
      //         color: Colors.white, size: 18),
      //   ),
      // ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: _primary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: _textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _primary, size: 20),
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13.sp,
            color: _textGrey,
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: _primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        validator: (v) => v!.isEmpty ? "Please enter $label" : null,
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    indent: 16.w,
    endIndent: 16.w,
    color: _border,
  );

  Widget _buildFileSection() {
    if (selectedFile != null) {
      final fileName = selectedFile!.path.split('/').last;
      final fileSize =
      (selectedFile!.lengthSync() / 1024).toStringAsFixed(1);
      final color = _fileColor(selectedFile!.path);

      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
          EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: Text(_fileIconEmoji(selectedFile!.path),
                  style: TextStyle(fontSize: 22.sp)),
            ),
          ),
          title: Text(
            fileName,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "$fileSize KB",
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: _textGrey,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: pickFile,
                child: Container(
                  padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    "Change",
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => setState(() => selectedFile = null),
                child: Container(
                  padding: EdgeInsets.all(5.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.red, size: 16.sp),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No file selected — upload zone
    return GestureDetector(
      onTap: pickFile,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 32.h),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _primary.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                color: _primary,
                size: 28.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              "Tap to attach a file",
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "PDF, DOC, JPG, PNG, XLS, CSV",
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: _textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 40.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : uploadAssignmentApi,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          disabledBackgroundColor: _primary.withOpacity(0.5),
          elevation: 4,
          shadowColor: _primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
          width: 22.w,
          height: 22.w,
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 8.w),
            Text(
              "Update Assignment",
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}