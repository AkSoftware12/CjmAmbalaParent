import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
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

  const AssignmentUpdateScreen({super.key, required this.onReturn,required this.id, required this.startDate, required this.endDate, required this.title, required this.descripation, required this.marks});

  @override
  _AssignmentUploadScreenState createState() => _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState extends State<AssignmentUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false; // Add this at the top of the class







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
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt','xls','csv'],
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


  Future<void> uploadAssignmentApi() async {

    try {
      setState(() {
        isLoading = true; // Show loader before API call
      });
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      print("Token: $token");

      String apiUrl = '${ApiRoutes.uploadTeacherAssignment}${'/'}${widget.id}';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add Headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      // Add Form Fields
      request.fields['title'] = titleController.text;
      request.fields['total_marks'] = totalMarksController.text;
      request.fields['description'] = descriptionController.text;
      request.fields['start_date'] = widget.startDate.toString().split(' ')[0];
      request.fields['end_date'] = widget.endDate.toString().split(' ')[0];
      request.fields['status'] = 1.toString();

      // Attach File

      if (selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attach',
            selectedFile!.path,
            filename: selectedFile!.path.split('/').last,
          ),
        );      }


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
          msg: "Assignment Update Successfully!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
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
    setState(() {
      titleController.text= widget.title;
      descriptionController.text= widget.descripation;
      totalMarksController.text= widget.marks;
    });

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,

      appBar: AppBar(
        title: Text("Update Assignment".toString().toUpperCase(),
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              color: AppColors2.textblack,
            ),
        ),
        backgroundColor: AppColors2.primary,
        iconTheme: IconThemeData(color: AppColors2.textblack,),
      ),

      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child:Padding(
            padding: EdgeInsets.all(0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [







                  SizedBox(height: 20,),
                  _buildTextField("Title", titleController),
                  SizedBox(height: 20,),

                  _buildTextField("Description", descriptionController, maxLines: 3),

                  SizedBox(height: 20),

                  // _buildTextField("Total Marks", totalMarksController, keyboardType: TextInputType.number),


                  SizedBox(height: 10),
                  _buildSelectedFile("Attach PDF", Icons.picture_as_pdf, pickFile, selectedPdf != null),

                  SizedBox(height: 20),



                  ElevatedButton(
                    onPressed: isLoading ? null : uploadAssignmentApi, // Disable button when loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                        : Text("Update Assignment".toString().toUpperCase(), style: TextStyle(fontSize: 16, color: Colors.white)),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors2.textblack),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color:  AppColors2.textblack),
        filled: false,
        fillColor:  AppColors2.textblack,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) => value!.isEmpty ? "Enter $label" : null,
    );
  }

  Widget _buildSelectedFile(String label, IconData icon, VoidCallback onTap, bool fileSelected) {
    return selectedFile != null
        ? Card(
      elevation: 3,
      color: AppColors2.textwhite,
      margin: EdgeInsets.symmetric(vertical: 10),
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
        child: Container(
          height:150,
            decoration: BoxDecoration(
                color: AppColors2.textwhite,
                borderRadius: BorderRadius.circular(10)
            ),
            child: Center(child: Text("No file selected", style: TextStyle(color: Colors.grey)))),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        border: Border.all(
          width: 1,
          color: Colors.black
        )
      ),

      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          date != null ? date.toString().split(' ')[0] : label,
          style: TextStyle(
            color: AppColors2.textblack,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.calendar_today, color:AppColors2.textblack,),
        onTap: onTap,
      ),
    );
  }


}
