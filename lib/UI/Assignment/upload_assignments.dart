import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart';

class AssignmentUploadScreen extends StatefulWidget {
  final String id;
  final VoidCallback onReturn;

  const AssignmentUploadScreen({
    super.key,
    required this.onReturn,
    required this.id,
  });

  @override
  _AssignmentUploadScreenState createState() => _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState extends State<AssignmentUploadScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  File? selectedFile;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  Future<void> uploadAssignmentApi() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please attach a file before submitting")),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("Token missing. Please login again.");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiRoutes.uploadAssignment),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['id'] = widget.id;
      request.files.add(
        await http.MultipartFile.fromPath(
          'attach',
          selectedFile!.path,
          filename: selectedFile!.path.split('/').last,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        widget.onReturn();
        Fluttertoast.showToast(
          msg: "Assignment Uploaded Successfully!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: const Color(0xFF1DB954),
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      } else {
        throw Exception("Failed: ${response.statusCode}");
      }
    } catch (e) {
      String msg = "Upload failed";
      if (e is SocketException) msg = "No internet connection.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'jpg':
      case 'png':
        return '🖼️';
      case 'doc':
        return '📝';
      default:
        return '📎';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0F0A0A);
    const Color surface = Color(0xFF1A1010);
    const Color cardBg = Color(0xFF1E1212);
    const Color accent = Color(0xFFB71C1C);
    const Color accentBright = Color(0xFFE53935);
    const Color accentSoft = Color(0x26B71C1C);
    const Color textPrimary = Color(0xFFFFF0F0);
    const Color textSecondary = Color(0xFF9E8A8A);
    const Color border = Color(0xFF3A1F1F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          "Upload Assignment",
          style: GoogleFonts.spaceGrotesk(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Header card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.upload_file_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Submit Your Work",
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Supported: PDF, JPG, PNG, DOC, TXT",
                                style: GoogleFonts.spaceGrotesk(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Attachment",
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // File drop zone / file card
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: selectedFile != null
                        ? _buildFileCard(
                            selectedFile!,
                            cardBg,
                            border,
                            textPrimary,
                            textSecondary,
                            accent,
                            accentSoft,
                          )
                        : _buildDropZone(
                            border,
                            textSecondary,
                            accentSoft,
                            accent,
                          ),
                  ),

                  const Spacer(),

                  // Upload button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : uploadAssignmentApi,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        disabledBackgroundColor: const Color(
                          0xFFB71C1C,
                        ).withOpacity(0.4),
                        elevation: 4,
                        shadowColor: const Color(0xFFB71C1C).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Upload Assignment",
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone(
    Color border,
    Color textSecondary,
    Color accentSoft,
    Color accent,
  ) {
    return GestureDetector(
      key: const ValueKey('dropzone'),
      onTap: pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: accent, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              "Tap to choose a file",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "PDF, DOC, JPG, PNG, TXT",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.red,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(
    File file,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    Color accentSoft,
  ) {
    final fileName = file.path.split('/').last;
    final ext = fileName.contains('.') ? fileName.split('.').last : 'file';
    final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
    final emoji = _getFileIcon(ext);

    return Container(
      key: const ValueKey('filecard'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1515),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$sizeKb KB",
                      style: GoogleFonts.spaceGrotesk(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => selectedFile = null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
