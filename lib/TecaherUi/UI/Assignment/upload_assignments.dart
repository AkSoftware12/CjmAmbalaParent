import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
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

class _AssignmentUploadScreenState extends State<AssignmentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false; // Add this at the top of the class
  List<Map<String, dynamic>> classes = [];
  List<Map<String,dynamic>> subject = [];
  List<Map<String,dynamic>> section = [];
  int? selectedClass;
  int? selectedSubject;
  int? selectedSection;





  // Date Pickers
  DateTime? startDate;
  DateTime? endDate;

  // File Upload
  File? selectedImage;
  File? selectedPdf;
  File? selectedFile; // Store the single selected file

  // Controllers
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController totalMarksController = TextEditingController();



  // Image Picker
  // Future<void> pickImage() async {
  //   final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       selectedImage = File(pickedFile.path);
  //     });
  //   }
  // }

  // PDF Picker

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt','xlsx','csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
        });
      } else {
        print("No file selected.");
      }
    } catch (e) {
      print("Error picking file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File picker is not working properly. Please restart the app.")),
      );
    }
  }



  // Date Picker Function
  Future<void> pickDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
          // sections = List<Map<String, dynamic>>.from(responseData['data']['sections']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load class and section data');
      }
    } catch (e) {
      print('Error fetching classes and sections: $e');
      setState(() {
        isLoading = false;
      });
    }
  }




  Future<void> uploadAssignmentApi() async {
    if (!_formKey.currentState!.validate()) {
      // If form validation fails, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields correctly!")),
      );
      return;
    }

    if (selectedClass == null || selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a Class and Subject")),
      );
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select start and end date")),
      );
      return;
    }

    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please attach a file before submitting")),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true; // Show loader before API call
      });
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      print("Token: $token");

      String apiUrl = '${ApiRoutes.uploadAssignment}';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add Headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      // Add Form Fields
      request.fields['class'] = selectedClass.toString() ?? "";
      request.fields['subject'] = selectedSubject.toString() ?? "";
      request.fields['title'] = titleController.text;
      request.fields['section'] = selectedSection.toString() ?? "";
      request.fields['total_marks'] = totalMarksController.text;
      request.fields['start_date'] = startDate?.toString().split(' ')[0] ?? "";
      request.fields['end_date'] = endDate?.toString().split(' ')[0] ?? "";
      request.fields['description'] = descriptionController.text;

      // Attach File
      request.files.add(
        await http.MultipartFile.fromPath(
          'attach',
          selectedFile!.path,
          filename: selectedFile!.path.split('/').last,
        ),
      );

      // Send Request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);


      setState(() {
        isLoading = false; // Hide loader after API call
      });
      if (response.statusCode == 200) {

        widget.onReturn();

        Fluttertoast.showToast(
          msg: "Assignment Uploaded Successfully!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 22.0,
        );

        // Navigate back after a short delay
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context);

        });

      } else {
        print("Failed to Upload: ${response.statusCode} - $jsonResponse");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload assignment: ${jsonResponse['message']}")),
        );
      }
    } catch (e) {
      print("Error Uploading File: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload assignment")),
      );
      setState(() {
        isLoading = false; // Hide loader on error
      });
    }
  }


  @override
  void initState() {
    super.initState();
    fetchClasses();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,

      appBar: AppBar(
        title: Text("Upload Assignment",
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              color: AppColors2.textblack,
            ),
        ),
        backgroundColor:AppColors2.primary,
        iconTheme: IconThemeData(color: AppColors2.textblack,),
      ),

      body: Padding(
        padding: EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child:Padding(
            padding: EdgeInsets.all(5),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // SizedBox(height: 20.sp,),

                  Container(
                    width: double.infinity,
                    height: 50.sp,
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
                      padding: EdgeInsets.all(0.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedClass,
                              decoration: const InputDecoration(
                                labelText: "Select Class",
                                border: InputBorder.none, // Removes the border
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),

                              ),

                              items: classes.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c["id"],
                                  child: Text(c["title"].toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedClass = value;
                                });
                              },

                            ),
                          ),

                        ],
                      ),


                    ),
                  ),

                  SizedBox(height: 10),
                  Container(
                    height: 50.sp,
                    width: double.infinity,
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
                      padding: EdgeInsets.all(0.0),
                      child: Row(
                        children: [
                          Expanded(
                            child:DropdownButtonFormField<int>(
                              value: selectedSection,
                              decoration: InputDecoration(
                                labelText: "Select Section",
                                border: InputBorder.none, // Removes the border

                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              ),

                              items: section.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c["id"],
                                  child: Text(c["title"].toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedSection = value;
                                });
                              },
                            ),

                          ),

                        ],
                      ),


                    ),
                  ),

                  SizedBox(height: 10),

                  // Section Dropdown (Only shows if a class is selected)

                  Container(
                    height: 50.sp,
                    width: double.infinity,
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
                      padding: EdgeInsets.all(0.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedSubject,
                              decoration: InputDecoration(
                                labelText: "Select Subject",
                                border: InputBorder.none, // Removes the border

                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              ),
                              items: subject.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c["id"],
                                  child: Text(c["subject_name"]),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedSubject = value;
                                });
                              },
                            ),




                          ),

                        ],
                      ),


                    ),
                  ),

                  SizedBox(height: 10),

                  Container(
                    height: 50.sp,
                    width: double.infinity,
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
                      padding: EdgeInsets.all(0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateTile("Start Date", startDate, () => pickDate(context, true)),
                          ),

                          Column(
                            children: [
                              Container(
                                width: 1.sp,
                                color: Colors.grey,
                                height: 50.sp,
                              )
                            ],

                          ),
                          Expanded(
                            child: _buildDateTile("End Date", endDate, () => pickDate(context, false)),
                          ),
                        ],
                      ),


                    ),
                  ),



                  SizedBox(height: 10,),
                  Container(
                    width: double.infinity,
                    height: 50.sp,
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
                      padding: EdgeInsets.all(5.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTextField("Title", titleController),

                          ),

                        ],
                      ),


                    ),
                  ),
                  SizedBox(height: 10),

                  // Container(
                  //   width: double.infinity,
                  //   height: 50.sp,
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(10),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: Colors.blue.withOpacity(0.2),
                  //         blurRadius: 8,
                  //         spreadRadius: 2,
                  //         offset: const Offset(0, 1),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Padding(
                  //     padding: EdgeInsets.all(5.0),
                  //     child: Row(
                  //       children: [
                  //         Expanded(
                  //           child: _buildTextField("Total Marks", totalMarksController, keyboardType: TextInputType.number),
                  //
                  //
                  //         ),
                  //
                  //       ],
                  //     ),
                  //
                  //
                  //   ),
                  // ),

                  Container(
                    width: double.infinity,
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
                      padding: EdgeInsets.all(5.0),
                      child: Row(
                        children: [
                          Expanded(
                            child:   _buildTextField("Description", descriptionController, maxLines: 3),





                          ),

                        ],
                      ),


                    ),
                  ),



                  SizedBox(height: 20),


                  SizedBox(height: 10),
                  _buildSelectedFile("Attach PDF", Icons.picture_as_pdf, pickFile, selectedPdf != null),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isLoading ? null : uploadAssignmentApi, // Disable button when loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 3,
                      ),
                    )
                        : Text("Upload Assignment", style: TextStyle(fontSize: 16, color: Colors.black)),
                  ),



                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),

    child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color:  Colors.black),
          border: InputBorder.none, // Removes the border
          filled: false,
          fillColor:  AppColors2.textblack,
        ),
        validator: (value) => value!.isEmpty ? "Enter $label" : null,
      ),
    );
  }

  Widget _buildSelectedFile(String label, IconData icon, VoidCallback onTap, bool fileSelected) {
    return selectedFile != null
        ? Card(
      elevation: 3,
      color: AppColors2.textwhite,
      margin: EdgeInsets.symmetric(vertical: 10,horizontal: 30),
      child: ListTile(
        leading: Icon(Icons.insert_drive_file, color: Colors.orange),
        title: Text(
          selectedFile!.path.split('/').last,
          style: TextStyle(color: Colors.black),
        ),
        subtitle: Text(
          "${(selectedFile!.lengthSync() / 1024).toStringAsFixed(2)} KB", // Show file size
          style: TextStyle(color: Colors.grey),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              selectedFile = null;
            });
          },
        ),
      ),
    )
        : Padding(
      padding: EdgeInsets.all(10),
      child: GestureDetector(
        onTap: pickFile,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10,horizontal: 30),
          child: Container(
            height:150,
              decoration: BoxDecoration(
                  color: AppColors2.textwhite,
                  borderRadius: BorderRadius.circular(10)
              ),
              child: Center(child: Text("No file selected", style: TextStyle(color: Colors.grey)))),
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return Container(
      height: 50.sp,
      decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),

      ),

      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        title: Text(
          date != null ? date.toString().split(' ')[0] : label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.calendar_today, color:Colors.black,size: 15.sp,),
        onTap: onTap,
      ),
    );
  }

}
