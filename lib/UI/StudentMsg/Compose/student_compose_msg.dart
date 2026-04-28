import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonCalling/data_not_found.dart';
import '../../../CommonCalling/progressbarWhite.dart';
import '../../../constants.dart';

class ComposeMesssageScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const ComposeMesssageScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<ComposeMesssageScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<ComposeMesssageScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  bool isSending = false;

  List messsage = [];
  List filteredMessages = [];

  PlatformFile? selectedFile;

  @override
  void initState() {
    super.initState();
    fetchAssignmentsData();
    _searchController.addListener(_filterMessages);
  }

  Future<void> fetchAssignmentsData() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getAllMessages),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        setState(() {
          messsage = jsonResponse['users'] ?? [];
          filteredMessages = messsage;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _filterMessages() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredMessages = messsage.where((user) {
        final name = user['first_name']?.toString().toLowerCase() ?? '';
        final designation =
            user['designation']?['title']?.toString().toLowerCase() ?? '';

        return name.contains(query) || designation.contains(query);
      }).toList();
    });
  }

  Future<void> _pickFile(StateSetter bottomSheetSetState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      bottomSheetSetState(() {
        selectedFile = result.files.first;
      });

      setState(() {
        selectedFile = result.files.first;
      });
    }
  }

  Future<void> _sendMessage({
    required String msg,
    required int senderId,
    required BuildContext sheetContext,
  }) async {
    final text = msg
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty && selectedFile == null) {
      _showSnackBar('Please enter message or select photo/pdf', Colors.red);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      _showSnackBar('Authentication token missing', Colors.red);
      return;
    }

    setState(() => isSending = true);

    try {
      final uri = Uri.parse(ApiRoutes.sendMessage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['receivers[]'] = 'user_$senderId';
      request.fields['body'] = text;

      final fileToSend = selectedFile;

      if (fileToSend != null && fileToSend.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            fileToSend.path!,
            filename: fileToSend.name,
          ),
        );
      } else {
        request.fields['attachment'] = '';
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      setState(() => isSending = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        selectedFile = null;

        Navigator.of(sheetContext).pop();

        _showSuccessDialog();
      } else {
        _showSnackBar(
          'Message failed: ${response.statusCode}\n$responseBody',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => isSending = false);

      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
          title: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green.shade100,
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 42,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Success",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "Message sent successfully",
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "OK",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessagePopup(
      BuildContext context,
      String name,
      String subtitle,
      int id,
      ) {
    final TextEditingController messageController = TextEditingController();

    selectedFile = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, bottomSheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 45.w,
                            height: 5.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                          ),
                        ),

                        SizedBox(height: 18.h),

                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22.r,
                              backgroundColor:
                              AppColors.primary.withOpacity(.12),
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send Message',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 18.h),

                        TextField(
                          controller: messageController,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'Type your message here...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        OutlinedButton.icon(
                          onPressed: isSending
                              ? null
                              : () => _pickFile(bottomSheetSetState),
                          icon: Icon(
                            Icons.attach_file_rounded,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'Attach Photo / PDF',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 44.h),
                            side: BorderSide(
                              color: AppColors.primary.withOpacity(.45),
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),

                        if (selectedFile != null) ...[
                          SizedBox(height: 10.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedFile!.extension
                                      ?.toLowerCase() ==
                                      'pdf'
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.image_rounded,
                                  color: selectedFile!.extension
                                      ?.toLowerCase() ==
                                      'pdf'
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    selectedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: isSending
                                      ? null
                                      : () {
                                    bottomSheetSetState(() {
                                      selectedFile = null;
                                    });
                                    setState(() {
                                      selectedFile = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 18.h),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSending
                                    ? null
                                    : () {
                                  selectedFile = null;
                                  Navigator.of(sheetContext).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                  EdgeInsets.symmetric(vertical: 13.h),
                                  side: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(width: 12.w),

                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isSending
                                    ? null
                                    : () {
                                  _sendMessage(
                                    msg: messageController.text,
                                    senderId: id,
                                    sheetContext: sheetContext,
                                  );
                                },
                                icon: isSending
                                    ? SizedBox(
                                  height: 18.sp,
                                  width: 18.sp,
                                  child:
                                  const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : Icon(
                                  Icons.send_rounded,
                                  size: 18.sp,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isSending ? 'Sending...' : 'Send',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding:
                                  EdgeInsets.symmetric(vertical: 13.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPermissionDeniedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 8.0,
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Permission Denied',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Sorry, you don\'t have permission to send messages at this time. Please contact support for assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[200],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8.sp,
              vertical: 5.sp,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or designation...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _filterMessages();
                  },
                )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const WhiteCircularProgressWidget()
                : filteredMessages.isEmpty
                ? const Center(
              child: DataNotFoundWidget(
                title: 'No Users Found.',
              ),
            )
                : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final user = filteredMessages[index];

                return GestureDetector(
                  onTap: () {
                    if (widget.messageSendPermissionsApp == 0) {
                      _showPermissionDeniedPopup(context);
                    } else {
                      _showMessagePopup(
                        context,
                        user['first_name']?.toString() ?? '',
                        user['designation']?['title']
                            ?.toString() ??
                            '',
                        user['id'],
                      );
                    }
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(
                      vertical: 3.sp,
                      horizontal: 8.sp,
                    ),
                    elevation: 6,
                    color: Colors.white,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11.sp),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: Row(
                        children: [
                          Container(
                            height: 35.sp,
                            width: 35.sp,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chat,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['first_name']
                                      ?.toString()
                                      .toUpperCase() ??
                                      '',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '(${user['designation']?['title']?.toString().toUpperCase() ?? ''})',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.attach_file_rounded,
                            size: 18.sp,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}