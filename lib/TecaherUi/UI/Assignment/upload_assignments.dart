import 'dart:convert';
import 'dart:io';
import 'package:avi/utils/date_time_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../constants.dart';

class AssignmentUploadScreen extends StatefulWidget {
  final VoidCallback onReturn;

  const AssignmentUploadScreen({super.key, required this.onReturn});

  @override
  _AssignmentUploadScreenState createState() => _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState extends State<AssignmentUploadScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> subject = [];
  List<Map<String, dynamic>> section = [];
  int? selectedClass;
  int? selectedSubject;
  int? selectedSection;

  DateTime? startDate;
  DateTime? endDate;

  File? selectedFile;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController totalMarksController = TextEditingController();

  static const Color _primaryRed = Color(0xFFB71C1C);
  static const Color _lightRed = Color(0xFFFFEBEE);
  static const Color _accentRed = Color(0xFFE53935);
  static const Color _borderColor = Color(0xFFEEEEEE);

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    fetchClasses();
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

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt', 'xlsx', 'csv'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File picker error. Please restart the app.")),
      );
    }
  }

  Future<void> pickDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> fetchClasses() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');
      final response = await http.get(
        Uri.parse(ApiRoutes.getTeacherTeacherSubject),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          classes = List<Map<String, dynamic>>.from(responseData['classes']);
          subject = List<Map<String, dynamic>>.from(responseData['subjects']);
          section = List<Map<String, dynamic>>.from(responseData['sections']);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> uploadAssignmentApi() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields correctly!")),
      );
      return;
    }
    if (selectedClass == null || selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Class and Subject")),
      );
      return;
    }
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end date")),
      );
      return;
    }
    try {
      setState(() => isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token missing. Please login again.")),
        );
        return;
      }
      final request =
      http.MultipartRequest('POST', Uri.parse(ApiRoutes.uploadTeacherAssignment));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['class'] = selectedClass.toString();
      request.fields['subject'] = selectedSubject.toString();
      request.fields['title'] = titleController.text;
      request.fields['start_date'] = startDate!.toString().split(' ')[0];
      request.fields['end_date'] = endDate!.toString().split(' ')[0];
      request.fields['description'] = descriptionController.text;

      if (selectedFile != null) {
        final filePath = selectedFile!.path;
        final fileName = filePath.split('/').last;
        request.files.add(
            await http.MultipartFile.fromPath('attach', filePath, filename: fileName));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      dynamic jsonResponse;
      try {
        jsonResponse = jsonDecode(responseBody);
      } catch (_) {
        jsonResponse = {"message": responseBody};
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      if (streamedResponse.statusCode == 200) {
        // 1. Toast pehle
        Fluttertoast.showToast(
          msg: "Assignment Uploaded Successfully!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        // 2. Parent refresh
        widget.onReturn();
        // 3. Ab screen back
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${jsonResponse['message'] ?? 'Unknown error'}")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload assignment")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          // physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("Assignment Details"),
                SizedBox(height: 8.h),
                _buildDropdownCard(
                  label: "Select Class",
                  icon: Icons.class_,
                  value: selectedClass,
                  items: classes.map((c) {
                    return DropdownMenuItem<int>(
                      value: c["id"],
                      child: Text(
                        '${c["academic_class"]['title']} (${c["section"]['title']})',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedClass = v),
                ),
                SizedBox(height: 10.h),
                _buildDropdownCard(
                  label: "Select Subject",
                  icon: Icons.book_outlined,
                  value: selectedSubject,
                  items: subject.map((c) {
                    return DropdownMenuItem<int>(
                      value: c["id"],
                      child: Text(
                        c["title"].toString(),
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedSubject = v),
                ),
                SizedBox(height: 20.h),
                _sectionLabel("Schedule"),
                SizedBox(height: 8.h),
                _buildDateRow(),
                SizedBox(height: 20.h),
                _sectionLabel("Content"),
                SizedBox(height: 8.h),
                _buildInputCard(
                  label: "Assignment Title",
                  icon: Icons.title_rounded,
                  controller: titleController,
                ),
                SizedBox(height: 10.h),
                _buildInputCard(
                  label: "Description",
                  icon: Icons.description_outlined,
                  controller: descriptionController,
                  maxLines: 4,
                ),
                SizedBox(height: 20.h),
                _sectionLabel("Attachment"),
                SizedBox(height: 8.h),
                _buildAttachmentSection(),
                SizedBox(height: 28.h),
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
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        "Upload Assignment",
        style: GoogleFonts.poppins(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryRed, _accentRed, Colors.orange.shade300],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16.sp,
          decoration: BoxDecoration(
            color: _primaryRed,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _primaryRed,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required IconData icon,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return _card(
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: value,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.red, size: 20.sp),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.sp,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: items,
              onChanged: onChanged,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.sp,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12.h : 0),
            child: Icon(icon, color: _primaryRed, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.black87),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 13.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (value) => value!.isEmpty ? "Enter $label" : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    return _card(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
                child: _buildDateTile("Start Date", startDate,
                    Icons.event_available_outlined, () => pickDate(context, true))),
            VerticalDivider(width: 1, color: _borderColor, thickness: 1),
            Expanded(
                child: _buildDateTile("End Date", endDate, Icons.event_busy_outlined,
                        () => pickDate(context, false))),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(
      String label, DateTime? date, IconData icon, VoidCallback onTap) {
    final bool hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon,
                color: hasDate ? _primaryRed : Colors.grey.shade400, size: 18.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    hasDate
                        ? AppDateTimeUtils.date(date.toString().split(' ')[0])
                        : "Tap to select",
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    if (selectedFile != null) {
      final String ext = selectedFile!.path.split('.').last.toUpperCase();
      final double sizeKb = selectedFile!.lengthSync() / 1024;
      final Color extColor = ext == 'PDF'
          ? Colors.red.shade700
          : (ext == 'DOC' ? Colors.blue.shade700 : Colors.orange.shade700);

      return _card(
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: extColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: extColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFile!.path.split('/').last,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "${sizeKb.toStringAsFixed(1)} KB",
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon:
              Icon(Icons.close_rounded, color: Colors.red.shade400, size: 20.sp),
              onPressed: () => setState(() => selectedFile = null),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: pickFile,
      child: Container(
        width: double.infinity,
        height: 120.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _primaryRed.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: _lightRed,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file_rounded, color: _primaryRed, size: 22.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "Tap to attach file",
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: _primaryRed,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              "PDF, DOC, JPG, PNG, XLSX, CSV",
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: Colors.grey.shade400,
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
          backgroundColor: _primaryRed,
          disabledBackgroundColor: _primaryRed.withOpacity(0.5),
          elevation: 4,
          shadowColor: _primaryRed.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? SizedBox(
          width: 22.w,
          height: 22.w,
          child: const CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_rounded, color: Colors.white),
            SizedBox(width: 10.w),
            Text(
              "Upload Assignment",
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}