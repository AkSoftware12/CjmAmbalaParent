import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonCalling/data_not_found.dart';
import '../../../../CommonCalling/progressbarWhite.dart';
import '../../../../constants.dart';

class AlumniComposeMessageScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const AlumniComposeMessageScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<AlumniComposeMessageScreen> createState() =>
      _AlumniComposeMessageScreenState();
}

class _AlumniComposeMessageScreenState
    extends State<AlumniComposeMessageScreen> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  bool isSending = false;

  List alumni = [];
  List filteredAlumni = [];

  /// ✅ Backend validator: 'alumni_ids' => 'required|array|min:1'
  /// 'alumni_ids.*' => 'integer|exists:alumni,id'
  Set<int> selectedAlumni = {};
  bool selectAllAlumni = false;

  PlatformFile? selectedFile;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterAlumni);
    fetchAlumni();
  }

  // ─────────────────────────────────────────────
  // FETCH ALUMNI  →  GET /api/alumnis
  // ─────────────────────────────────────────────
  Future<void> fetchAlumni() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        _showErrorSnackBar('No token found. Please log in.');
        return;
      }

      final response = await http.get(
        Uri.parse(ApiRoutes.getAdminAlumniList),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
        json.decode(response.body) as Map<String, dynamic>;

        final List list = data['alumni'] ?? [];

        if (!mounted) return;
        setState(() {
          alumni = list;
          filteredAlumni = alumni;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
        _showErrorSnackBar(
          'Failed to load alumni (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('Error fetching alumni: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar('Error fetching alumni: $e');
    }
  }

  // ─────────────────────────────────────────────
  // SEARCH FILTER (name / email / phone)
  // ─────────────────────────────────────────────
  void _filterAlumni() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredAlumni = alumni.where((a) {
        final name = a['full_name']?.toString().toLowerCase() ?? '';
        final email = a['email']?.toString().toLowerCase() ?? '';
        final phone = a['phone']?.toString().toLowerCase() ?? '';
        return name.contains(query) ||
            email.contains(query) ||
            phone.contains(query);
      }).toList();

      selectAllAlumni = filteredAlumni.isNotEmpty &&
          filteredAlumni.every(
                (a) => selectedAlumni.contains(a['id'] as int),
          );
    });
  }

  // ─────────────────────────────────────────────
  // SELECTION
  // ─────────────────────────────────────────────
  void _toggleSelection(int id) {
    setState(() {
      if (selectedAlumni.contains(id)) {
        selectedAlumni.remove(id);
        debugPrint('🔴 Alumni removed $id');
      } else {
        selectedAlumni.add(id);
        debugPrint('✅ Alumni added $id');
      }

      selectAllAlumni = filteredAlumni.isNotEmpty &&
          filteredAlumni.every(
                (a) => selectedAlumni.contains(a['id'] as int),
          );
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (selectAllAlumni) {
        selectedAlumni.clear();
        selectAllAlumni = false;
        debugPrint('🔴 [SELECT ALL ALUMNI] → DESELECTED');
      } else {
        selectedAlumni
          ..clear()
          ..addAll(filteredAlumni.map((a) => a['id'] as int));
        selectAllAlumni = true;
        debugPrint(
          '✅ [SELECT ALL ALUMNI] → ${selectedAlumni.length} selected',
        );
      }
    });
  }

  // ─────────────────────────────────────────────
  // FILE PICKER
  // ─────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => selectedFile = result.files.first);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  // ─────────────────────────────────────────────
  // SEND MESSAGE → POST alumni/message/principal/send
  //
  // Validator:
  //   alumni_ids   => required|array|min:1
  //   alumni_ids.* => integer|exists:alumni,id
  //   message      => required_without:attachment|string|nullable
  //   attachment   => nullable|file|max:10240
  // ─────────────────────────────────────────────
  Future<void> _sendMessage() async {
    if (isSending) return;

    final text = messageController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    // message required_without:attachment
    if (text.isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    // alumni_ids required|min:1
    if (selectedAlumni.isEmpty) {
      _showErrorSnackBar('Please select at least one alumni');
      return;
    }

    if (widget.messageSendPermissionsApp == 0) {
      _showPermissionDeniedPopup(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null || token.isEmpty) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    setState(() => isSending = true);

    try {
      final uri = Uri.parse(ApiRoutes.sendAdminAlumniMsg);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // ✅ alumni_ids as array → alumni_ids[0], alumni_ids[1], ...
      final ids = selectedAlumni.toList();
      for (int i = 0; i < ids.length; i++) {
        request.fields['alumni_ids[$i]'] = ids[i].toString();
      }

      // ✅ message
      if (text.isNotEmpty) {
        request.fields['message'] = text;
      }

      debugPrint('📤 alumni_ids → $ids');
      debugPrint('📤 message → $text');

      // ✅ attachment (max:10240 KB = 10 MB)
      if (selectedFile != null && selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            selectedFile!.path!,
            filename: selectedFile!.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      debugPrint('📥 Send status → ${response.statusCode}');
      debugPrint('📥 Send body   → ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetUI();
        _showSuccessPopup(context);
      } else if (response.statusCode == 422) {
        // Validation errors → 'errors' => $validator->errors()->first()
        String msg = 'Validation errors';
        try {
          final data = jsonDecode(response.body);
          msg = data['errors']?.toString() ??
              data['message']?.toString() ??
              msg;
        } catch (_) {}
        _showErrorSnackBar(msg);
      } else {
        _showErrorSnackBar('Failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  void _resetUI() {
    if (!mounted) return;
    setState(() {
      messageController.clear();
      selectedFile = null;
      selectedAlumni.clear();
      selectAllAlumni = false;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
                    'Sorry, you don\'t have permission to send messages at this time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: Colors.grey[200]),
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

  void _showSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Success 🎉",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Message sent successfully!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 5.sp),

          // ─── Search Bar ───
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.sp),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search alumni...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon:
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.grey, size: 18),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          SizedBox(height: 5.sp),

          // ─── Header: Select All + Count ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Card(
                color: Colors.grey.shade100,
                child: SizedBox(
                  width: 150.sp,
                  height: 30.sp,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.sp,
                      vertical: 5.sp,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selectAllAlumni,
                          onChanged: (value) => _toggleSelectAll(),
                          activeColor: AppColors.primary,
                        ),
                        Text(
                          'Select All',
                          style: GoogleFonts.montserrat(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (selectedAlumni.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: 8.sp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade800,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selectedAlumni.length} Selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 5.sp),

          // ─── Alumni List ───
          Expanded(
            child: isLoading
                ? const WhiteCircularProgressWidget()
                : filteredAlumni.isEmpty
                ? const Center(
              child:
              DataNotFoundWidget(title: 'No Alumni Found.'),
            )
                : ListView.builder(
              itemCount: filteredAlumni.length,
              itemBuilder: (context, index) {
                final item = filteredAlumni[index];
                final id = item['id'] as int;
                final isSelected = selectedAlumni.contains(id);

                return GestureDetector(
                  onLongPress: () => _toggleSelection(id),
                  child: Card(
                    margin: EdgeInsets.symmetric(
                      vertical: 3.sp,
                      horizontal: 5.sp,
                    ),
                    color: isSelected
                        ? Colors.blue.shade50
                        : Colors.white,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11.sp),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) =>
                              _toggleSelection(id),
                          activeColor: AppColors.primary,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['full_name']
                                    ?.toString()
                                    .toUpperCase() ??
                                    'UNKNOWN',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item['email']?.toString() ?? '',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                item['phone']?.toString() ?? '',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(height: 3.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Message Input ───
          SafeArea(
            child: Card(
              color: Colors.grey.shade300,
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 5.sp,
                  vertical: 15.sp,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: AppColors2.primary),
                      onPressed: _pickFile,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                maxLines: 5,
                                minLines: 1,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                TextCapitalization.sentences,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14.sp,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ),
                            if (selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  selectedFile!.name,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors2.primary,
                      child: IconButton(
                        icon: isSending
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    messageController.dispose();
    super.dispose();
  }
}