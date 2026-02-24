
import 'package:avi/TecaherUi/UI/Assignment/update_assignments.dart';
import 'package:avi/TecaherUi/UI/Assignment/upload_assignments.dart' show AssignmentUploadScreen;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../constants.dart';
import '../../../utils/textSize.dart';
import 'package:html/parser.dart' as html_parser;

import 'assinment_detail.dart';

class AssignmentListScreen extends StatefulWidget {
  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  bool isLoading = true;
  List assignments = []; // Declare a list to hold API data

  @override
  void initState() {
    super.initState();

    DateTime.now().subtract(const Duration(days: 30));

    fetchAssignmentsData();
  }

  void _refresh() {
    setState(() {
      fetchAssignmentsData();
    });
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    print("Token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getTeacherAssignments),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Url :- ${ApiRoutes.getTeacherAssignments}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        assignments = jsonResponse['data'];
        isLoading = false; // Stop progress bar
// Update state with fetched data
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  // HexColor('#003366').withOpacity(0.5),
                  AppColors2.primary,
                  AppColors2.primary,
                ],
                // Change colors as needed
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Column(
            children: [
              Card(
                // color: HexColor('#7a211b'),
                color: AppColors2.primary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(30), // Optional rounded corners
                ),
                elevation: 1,
                // Adds shadow for better visibility
                margin: EdgeInsets.all(0),
                // Adds some space around the card
                child: Container(
                  // color: Colors.transparent,
                  width: double.infinity, // Makes the card expand horizontally
                  padding: EdgeInsets.all(5.sp), // Adds padding inside the card
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40.sp,
                      ),
                      Stack(
                        children: [
                          Container(
                            height: 55.sp,
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        icon: Icon(Icons.arrow_back_ios,
                                            size: 20.sp, color: Colors.white),
                                      ),
                                      SizedBox(
                                        width: 10.sp,
                                      ),
                                      Text(
                                        'Assignment',
                                        style: GoogleFonts.poppins(
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .displayLarge,
                                          fontSize: TextSizes.textmedium,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.normal,
                                          color: AppColors2.textblack,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                      padding: EdgeInsets.only(right: 8.sp),
                                      child: Container(
                                        height: 30.sp,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.blue,
                                              Colors.purple
                                            ], // Gradient colors
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(20
                                              .sp), // Optional: Rounded corners
                                        ),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            // Make button transparent
                                            shadowColor: Colors.transparent,
                                            // Remove shadow
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 0),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                transitionDuration:
                                                    Duration(milliseconds: 500),
                                                // Animation Speed
                                                pageBuilder: (context,
                                                        animation,
                                                        secondaryAnimation) =>
                                                    AssignmentUploadScreen(
                                                        onReturn: _refresh),
                                                transitionsBuilder: (context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child) {
                                                  var begin = Offset(1.0,
                                                      0.0); // Right to Left
                                                  var end = Offset.zero;
                                                  var tween = Tween(
                                                          begin: begin,
                                                          end: end)
                                                      .chain(CurveTween(
                                                          curve: Curves
                                                              .easeInOut));

                                                  return SlideTransition(
                                                    position:
                                                        animation.drive(tween),
                                                    child: child,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                          icon: Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 16.sp,
                                            color: Colors.white,
                                          ),
                                          // Upload icon
                                          label: Text(
                                            'Create Task',
                                            style: GoogleFonts.poppins(
                                              textStyle: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              fontStyle: FontStyle.normal,
                                              color: AppColors2.textwhite,
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 25.sp,
              ),
              Row(
                children: [
                  SizedBox(width: 5.sp),
                  Icon(
                    Icons.assignment, // Assignment icon
                    color: AppColors2.textwhite, // Match text color
                    size: 22.sp, // Adjust size as needed
                  ),
                  SizedBox(width: 8.sp), // Spacing between icon and text
                  Text(
                    'Assignment List',
                    style: GoogleFonts.poppins(
                      textStyle: Theme.of(context).textTheme.displayLarge,
                      fontSize: TextSizes.textmedium,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                      color: AppColors2.textwhite,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 5.sp,
              ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: CupertinoActivityIndicator(
                              radius: 25,
                              color: AppColors2.primary,
                            )))
                    : assignments.isEmpty
                        ? Center(
                            child: DataNotFoundWidget(
                            title: 'Assignments  Not Available.',
                          ))
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: ListView.builder(
                                  itemCount: assignments.length,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 0),
                                  itemBuilder: (context, index) {
                                    final assignment = assignments[index];
                                    String description = html_parser
                                            .parse(assignment['description'])
                                            .body
                                            ?.text ??
                                        '';
                                    String startDate = DateFormat('dd-MM-yyyy')
                                        .format(DateTime.parse(
                                            assignment['start_date']));
                                    String endDate = DateFormat('dd-MM-yyyy')
                                        .format(DateTime.parse(
                                            assignment['end_date']));

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AssignmentDetailScreen(id: assignment['id'],)),
                                        );
                                      },
                                      child: Card(
                                        margin: EdgeInsets.symmetric(
                                            vertical: 5.sp, horizontal: 5.sp),
                                        elevation: 0,
                                        color: Colors.grey.shade200,
                                        // Light background
                                        shadowColor: Colors.black26,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(6.sp),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  /// **Title & Index**
                                                  Row(
                                                    children: [
                                                      Container(
                                                        height: 35.sp,
                                                        width: 35.sp,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.blueAccent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(15),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '${index + 1}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 15),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              assignment[
                                                                      'title']
                                                                  .toString()
                                                                  .toUpperCase(),
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            SizedBox(height: 5),
                                                            Text(
                                                              description
                                                                  .toUpperCase(),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  SizedBox(height: 5.sp),

                                                  /// **Dates**
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      _buildDateInfo(
                                                          'Start',
                                                          startDate,
                                                          Icons.calendar_today),
                                                      _buildDateInfo(
                                                          'End',
                                                          endDate,
                                                          Icons.calendar_today),



                                                    ],
                                                  ),

                                                  SizedBox(height: 10.sp),

                                                  Divider(
                                                    height: 2.sp,
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    thickness: 2.sp,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                  // color: Colors.black26,
                                                  // gradient: LinearGradient(
                                                  //   colors: [HexColor('#7a211b').withOpacity(0.8), HexColor('#003366').withOpacity(0.8)],
                                                  //   // Change colors as needed
                                                  //   begin: Alignment.topLeft,
                                                  //   end: Alignment.bottomRight,
                                                  // ),

                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Padding(
                                                padding: EdgeInsets.all(5.sp),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    _buildButton(
                                                      text: 'View',
                                                      icon: Icons
                                                          .remove_red_eye_outlined,
                                                      color: Colors.blueAccent,
                                                      onTap: () async {

                                                        if (await canLaunchUrl(Uri.parse(assignment['attach_url'].toString()))) {
                                                          await launchUrl(Uri.parse(assignment['attach_url'].toString()), mode: LaunchMode.externalApplication);
                                                        } else {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Could not download file')),
                                                          );
                                                        }
                                                        // Navigator.push(
                                                        //   context,
                                                        //   MaterialPageRoute(builder: (context) =>  WebViewPage(url: '${assignment['attach_url'].toString()}',
                                                        //
                                                        //   )),
                                                        // );



                                                        // final Uri _url = Uri
                                                        //     .parse(assignment[
                                                        //             'attach_url']
                                                        //         .toString());
                                                        //
                                                        // if (!await launchUrl(
                                                        //     _url)) {
                                                        //   throw Exception(
                                                        //       'Could not launch $_url');
                                                        // }

                                                      },
                                                    ),
                                                    _buildButton(
                                                      text: 'Edit',
                                                      icon: Icons.edit,
                                                      color: Colors.orange,
                                                      onTap: () {
                                                        _showUpdateConfirmationDialog(
                                                          assignment['id'],
                                                          assignment[
                                                                  'start_date']
                                                              .toString(),
                                                          assignment['end_date']
                                                              .toString(),
                                                          assignment['title']
                                                              .toString(),
                                                          assignment[
                                                                  'description']
                                                              .toString(),
                                                          assignment[
                                                                  'total_marks']
                                                              .toString(),
                                                        );
                                                      },
                                                      // onTap: () {
                                                      //   Navigator.push(
                                                      //     context,
                                                      //     MaterialPageRoute(builder: (context) =>  MyAppDiolog(
                                                      //
                                                      //     )),
                                                      //   );
                                                      // },
                                                    ),
                                                    _buildButton(
                                                      text: 'DELETE',
                                                      icon: Icons.delete,
                                                      color: Colors.redAccent,
                                                      onTap: () =>
                                                          _showDeleteConfirmationDialog(
                                                              assignment['id']
                                                                  .toString()), // Call delete confirmation
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              )
            ],
          ),
        ],
      ),
    );
  }

  /// **Reusable Widget for Date**
  Widget _buildDateInfo(String label, String date, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54), // Add Icon
            SizedBox(width: 4), // Space between icon and text
            Text(
              date,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// **Reusable Button Widget**
  Widget _buildButton({
    required String text,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, // Increased width to fit the icon
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min, // Adjust to fit content
            children: [
              Icon(icon, color: Colors.white, size: 16), // Icon added
              SizedBox(width: 5), // Space between icon and text
              Text(
                text.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(String assignmentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Rounded Corners
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              // Warning Icon
              SizedBox(width: 10),
              Text("Confirm Delete",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Are you sure you want to delete this assignment?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red Delete Button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _deleteAssignment(assignmentId); // Call API
              },
              child: Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateConfirmationDialog(int id, String startDate, String endDate,
      String title, String descripation, String marks) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 50),
                SizedBox(height: 12),
                Text(
                  "Update Assignment",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
                ),
                SizedBox(height: 8),
                Text(
                  "Are you sure you want to update this assignment?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel".toUpperCase(),
                          style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: Duration(milliseconds: 500),
                            // Animation Speed
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    AssignmentUpdateScreen(
                              onReturn: _refresh,
                              startDate: startDate,
                              endDate: endDate,
                              id: id,
                              title: title,
                              descripation: descripation,
                              marks: marks,
                            ),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              var begin = Offset(1.0, 0.0); // Right to Left
                              var end = Offset.zero;
                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: Curves.easeInOut));

                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Text("Update".toUpperCase(),
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken'); // Retrieve Token
      print("Token: $token");

      String apiUrl = "${ApiRoutes.deleteTeacherAssignment}/$assignmentId"; // API URL

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $token", // Include token
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        print("Assignment Deleted Successfully!");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Assignment Deleted Successfully!")),
        );
        _refresh();

        // Refresh List After Deletion
        setState(() {
          assignments.removeWhere((item) => item['id'] == assignmentId);
        });
      } else {
        print("Failed to Delete: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete assignment")),
        );
      }
    } catch (e) {
      print("Error Deleting Assignment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error occurred while deleting")),
      );
    }
  }
}
