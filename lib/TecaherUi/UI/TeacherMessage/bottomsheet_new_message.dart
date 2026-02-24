import 'package:animated_search_bar/animated_search_bar.dart';
// import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../CommonCalling/progressbarWhite.dart';
import '../../../constants.dart';
import 'chat.dart';

class NewTeacherMessageScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const NewTeacherMessageScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<NewTeacherMessageScreen> createState() =>
      _NewTeacherMessageScreenState();
}

class _NewTeacherMessageScreenState extends State<NewTeacherMessageScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  List messsage = [];
  List students = [];
  List filteredMessages = [];
  List filteredMessages2 = [];
  Set<String> selectedTeachers = {};
  Set<String> selectedStudents = {};
  late TabController _tabController;
  bool selectAllTeachers = false;
  bool selectAllStudents = false;
  PlatformFile? selectedFile;
  bool isSending = false;

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> section = [];
  int? selectedClass; // Initialize as null
  int? selectedSection; // Initialize as null

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterMessages);
    _tabController.addListener(_onTabChanged);
    fetchClasses(); // Fetch classes and sections, and set default values afterward
  }

  void _onTabChanged() {
    setState(() {
      _searchController.clear();
      _filterMessages();
    });
  }

  Future<void> fetchClasses() async {
    setState(() {
      isLoading = true;
    });

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
          section = List<Map<String, dynamic>>.from(responseData['sections']);
          isLoading = false;

          // Debug: Check for duplicate IDs
          _checkForDuplicateIds(classes, 'classes');
          _checkForDuplicateIds(section, 'sections');

          // Set default values only if lists are not empty
          if (classes.isNotEmpty) {
            selectedClass = 0;
          }
          if (section.isNotEmpty) {
            selectedSection = 0;
            fetchAssignmentsData(); // Fetch data after setting section
          }
        });
      } else {
        throw Exception('Failed to load class and section data');
      }
    } catch (e) {
      print('Error fetching classes and sections: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching classes: $e')));
    }
  }

  // Helper function to check for duplicate IDs in a list
  void _checkForDuplicateIds(List<Map<String, dynamic>> list, String listName) {
    final idSet = <int>{};
    for (var item in list) {
      final id = item['id'] as int;
      if (idSet.contains(id)) {
        print('Warning: Duplicate ID $id found in $listName');
      } else {
        idSet.add(id);
      }
    }
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      // Build the query parameters dynamically
      final queryParams = <String, String>{};
      if (selectedClass != null) {
        queryParams['class_id'] = selectedClass.toString();
      }
      if (selectedSection != null) {
        queryParams['section_id'] = selectedSection.toString();
      }

      // Construct the URI with query parameters
      final uri = Uri.parse(
        ApiRoutes.getAllTeacherMessages,
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          messsage = jsonResponse['users'] ?? [];
          students = jsonResponse['students'] ?? [];
          filteredMessages = messsage;
          filteredMessages2 = students;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to fetch data.')));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _filterMessages() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (_tabController.index == 0) {
        filteredMessages = messsage.where((assignment) {
          final name = assignment['first_name']?.toString().toLowerCase() ?? '';
          final designation = assignment['designation']?.toString().toLowerCase() ?? '';
          // final designation =
          //     assignment['designation']?['title']?.toString().toLowerCase() ??
          //     '';
          return name.contains(query) || designation.contains(query);
        }).toList();
      } else {
        filteredMessages2 = students.where((assignment) {
          final name =
              assignment['student_name']?.toString().toLowerCase() ?? '';
          final className =
              assignment['class_name']?.toString().toLowerCase() ?? '';
          return name.contains(query) || className.contains(query);
        }).toList();
      }
    });
  }


  Future<void> _sendMessage() async {
    if (isSending) return; // ✅ double tap block

    if (messageController.text.trim().isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    if (widget.messageSendPermissionsApp == 0) {
      _showPermissionDeniedPopup(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    setState(() => isSending = true); // ✅ start loader

    try {
      final uri = Uri.parse(ApiRoutes.sendTeacherMessage);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      List<String> receivers = [...selectedTeachers, ...selectedStudents];
      request.fields['receivers'] = jsonEncode(receivers);
      request.fields['body'] = messageController.text.trim();

      if (selectedFile != null && selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            selectedFile!.path!,
            filename: selectedFile!.name,
          ),
        );
      } else {
        request.fields['attachment'] = '';
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        messageController.clear();
        setState(() {
          selectedFile = null;
          selectedTeachers.clear();
          selectedStudents.clear();
          selectAllTeachers = false;
          selectAllStudents = false;
        });

        _showSuccessPopup(context);
      } else {
        _showErrorSnackBar('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error sending message: $e');
    } finally {
      if (mounted) setState(() => isSending = false); // ✅ stop loader
    }
  }
  void _showErrorSnackBar(String message) {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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

  void _toggleSelection(int id) {
    setState(() {
      if (_tabController.index == 0) {
        final teacherId = "user_$id";
        if (selectedTeachers.contains(teacherId)) {
          selectedTeachers.remove(teacherId);
        } else {
          selectedTeachers.add(teacherId);
        }
        selectAllTeachers = selectedTeachers.length == messsage.length;
      } else {
        final studentId = "student_$id";
        if (selectedStudents.contains(studentId)) {
          selectedStudents.remove(studentId);
        } else {
          selectedStudents.add(studentId);
        }
        selectAllStudents = selectedStudents.length == students.length;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_tabController.index == 0) {
        if (selectAllTeachers) {
          selectedTeachers.clear();
        } else {
          selectedTeachers.addAll(messsage.map((user) => "user_${user['id']}"));
        }
        selectAllTeachers = !selectAllTeachers;
      } else {
        if (selectAllStudents) {
          selectedStudents.clear();
        } else {
          selectedStudents.addAll(
            students.map((student) => "student_${student['id']}"),
          );
        }
        selectAllStudents = !selectAllStudents;
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
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
                // ✅ Success Icon
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),

                SizedBox(height: 15),

                // ✅ Title
                Text(
                  "Success 🎉",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 10),

                // ✅ Message
                Text(
                  "Message sent successfully!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),

                SizedBox(height: 20),

                // ✅ Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text("OK",style: TextStyle(color: Colors.white),),
                  ),
                )
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(35.sp), // 👈 Custom Height
        child: AppBar(
          backgroundColor: AppColors.secondary,
          centerTitle: true,
          leading: SizedBox(
            height: 50.sp,
            child: Center(
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 25.sp,
                ),
                onPressed: () {
                  Navigator.pop(context); // Back action
                },
              ),
            ),
          ),
          title: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            height: 30.sp,
            child: AnimatedSearchBar(
              label: 'Compose Messages',
              controller: _searchController,
              labelStyle: GoogleFonts.montserrat(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
                color: AppColors.textwhite,
              ),
              searchStyle: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              closeIcon: Icon(Icons.close,color: Colors.white,),
              searchIcon: Icon(Icons.search,color: Colors.white,),// 🔥 Close icon white
              textInputAction: TextInputAction.done,
              autoFocus: false,
              searchDecoration: const InputDecoration(
                hintText: 'Search',
                alignLabelWithHint: true,
                fillColor: Colors.white,
                focusColor: Colors.white,
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                debugPrint('value on Change: $value');
                setState(() {});
              },
              onFieldSubmitted: (value) {
                debugPrint('value on Field Submitted: $value');
                setState(() {});
              },
            )

          ),
          actions: [
            Padding(
              padding:  EdgeInsets.only(right: 8.sp),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  messageController.clear();
                  setState(() {
                    selectedFile = null;
                    selectedTeachers.clear();
                    selectedStudents.clear();
                    selectAllTeachers = false;
                    selectAllStudents = false;
                    selectedClass = null;
                    selectedSection = null;
                  });
                  fetchAssignmentsData();
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent, // Add this to remove the grey line
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
                color: Colors.red.shade800,
              ),
              indicatorSize: TabBarIndicatorSize.tab, // Ensure indicator respects tab boundaries
              labelColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 15.sp, // Set your desired font size
                fontWeight: FontWeight.bold, // Optional: Adjust font weight if needed
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 13.sp, // Slightly smaller font size for unselected tabs
                fontWeight: FontWeight.bold, // Optional: Different weight for unselected tabs
              ),
              unselectedLabelColor: Colors.black,
              tabs: [
                Tab(
                  child: Container(
                    alignment: Alignment.center, // Explicitly center the text
                    child: Text(
                      'Teachers (${filteredMessages.length})',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Tab(
                  child: Container(
                    alignment: Alignment.center, // Explicitly center the text
                    child: Text(
                      'Students (${filteredMessages2.length})',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Visibility(
            visible: _tabController.index == 1,
            child: Card(
              color: Colors.white70,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.sp,
                              vertical: 5.sp,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Class',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.sp),
                            child: Container(
                              width: double.infinity,
                              height: 40.sp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FocusScope(
                                        canRequestFocus: false,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField<int?>(
                                            value:
                                                classes.isNotEmpty &&
                                                    classes.any(
                                                      (c) =>
                                                          c["id"] == selectedClass,
                                                    )
                                                ? selectedClass
                                                : null,
                                            decoration: const InputDecoration(
                                              hintText: "Select Class",
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 0,
                                              ),
                                            ),
                                            icon: const SizedBox.shrink(),
                                            items: classes.isNotEmpty
                                                ? classes.map((c) {
                                                    return DropdownMenuItem<int>(
                                                      value: c["id"],
                                                      child: Text(
                                                        c["title"]?.toString() ??
                                                            'Unknown',
                                                      ),
                                                    );
                                                  }).toList()
                                                : [
                                                    const DropdownMenuItem<int>(
                                                      value: null,
                                                      child: Text(
                                                        "No Classes Available",
                                                      ),
                                                    ),
                                                  ],
                                            onChanged: classes.isNotEmpty
                                                ? (value) {
                                                    setState(() {
                                                      selectedClass = value;
                                                      // fetchAssignmentsData();
                                                    });
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Center(
                                      child: Icon(
                                        Icons.arrow_drop_down,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.sp,
                              vertical: 5.sp,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Section',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.sp),
                            child: Container(
                              width: double.infinity,
                              height: 40.sp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField<int?>(
                                          isExpanded: true, // ✅ very important
                                          value: (section.isNotEmpty &&
                                              section.any((s) => s["id"] == selectedSection))
                                              ? selectedSection
                                              : null,
                                          decoration: const InputDecoration(
                                            hintText: "Select Section",
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                          ),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20,), // ✅ keep a small icon
                                          selectedItemBuilder: (context) {
                                            if (section.isEmpty) {
                                              return [
                                                const Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    "No Sections Available",
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ];
                                            }
                                            return section.map<Widget>((s) {
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  (s["title"] ?? "Unknown").toString(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  softWrap: false,
                                                ),
                                              );
                                            }).toList();
                                          },
                                          items: section.isNotEmpty
                                              ? section.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s["id"],
                                              child: Text(
                                                (s["title"] ?? "Unknown").toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis, // ✅ menu text bhi safe
                                              ),
                                            );
                                          }).toList()
                                              : const [
                                            DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text("No Sections Available"),
                                            ),
                                          ],
                                          onChanged: section.isNotEmpty
                                              ? (value) {
                                            setState(() {
                                              selectedSection = value;
                                            });
                                            fetchAssignmentsData();
                                          }
                                              : null,
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 10.sp,
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Card(
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
                      Transform.scale(
                        scale: 1,
                        child: Checkbox(
                          value: _tabController.index == 0
                              ? selectAllTeachers
                              : selectAllStudents,
                          onChanged: (value) => _toggleSelectAll(),
                          activeColor: AppColors.primary,
                        ),
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
          ),
          SizedBox(
            height: 10.sp,
          ),


          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                isLoading
                    ? const WhiteCircularProgressWidget()
                    : filteredMessages.isEmpty
                    ? const Center(
                        child: DataNotFoundWidget(title: 'No Teachers Found.'),
                      )
                    : ListView.builder(
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final assignment = filteredMessages[index];
                          final isSelected = selectedTeachers.contains(
                            'user_${assignment['id']}',
                          );
                          return GestureDetector(
                            onLongPress: () =>
                                _toggleSelection(assignment['id']),
                            child: Card(
                              margin: EdgeInsets.symmetric(
                                vertical: 3.sp,
                                horizontal: 5.sp,
                              ),
                              // elevation: 6,
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.sp),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(0.sp),
                                child: Row(
                                  children: [
                                    Transform.scale(
                                      scale: 1,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (value) =>
                                            _toggleSelection(assignment['id']),
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${assignment['first_name']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '(${assignment['designation'].toString().toUpperCase() ?? 'NO DESIGNATION'})',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                isLoading
                    ? const WhiteCircularProgressWidget()
                    : filteredMessages2.isEmpty
                    ? const Center(
                        child: DataNotFoundWidget(title: 'No Students Found.'),
                      )
                    : ListView.builder(
                        itemCount: filteredMessages2.length,
                        itemBuilder: (context, index) {
                          final assignment = filteredMessages2[index];
                          final isSelected = selectedStudents.contains(
                            'student_${assignment['id']}',
                          );
                          return GestureDetector(
                            onLongPress: () =>
                                _toggleSelection(assignment['id']),
                            child: Card(
                              margin: EdgeInsets.symmetric(
                                vertical: 3.sp,
                                horizontal: 5.sp,
                              ),
                              // elevation: 6,
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11.sp),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(0.sp),
                                child: Row(
                                  children: [
                                    Transform.scale(
                                      scale: 1,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (value) =>
                                            _toggleSelection(assignment['id']),
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assignment['student_name']?.toString().toUpperCase() ?? 'UNKNOWN',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${assignment['class']?.toString().toUpperCase()}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          SafeArea(
            child: Card(
              color: Colors.grey.shade300,
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(00.0),
                  // Use 10.sp if using flutter_screenutil
                  topRight: Radius.circular(
                    00.0,
                  ), // Use 10.sp if using flutter_screenutil
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
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  border: InputBorder.none,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: isSending ? null : _sendMessage, // ✅ disable while sending
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
    _tabController.dispose();
    super.dispose();
  }
}




