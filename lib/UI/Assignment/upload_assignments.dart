import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart';

class AssignmentUploadScreen extends StatefulWidget {
  final String id;
  final VoidCallback onReturn;

  const AssignmentUploadScreen({super.key, required this.onReturn, required this.id});

  @override
  _AssignmentUploadScreenState createState() => _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState extends State<AssignmentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false; // Add this at the top of the class



  // File Upload
  File? selectedImage;
  File? selectedPdf;
  File? selectedFile; // Store the single selected file





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
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'txt'],
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
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception("Token is missing. Please login again.");
      }

      String apiUrl = ApiRoutes.uploadAssignment;
      print("API URL: $apiUrl");

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // ✅ Add Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // ✅ Convert `id` to int and then to String
      int assignmentId = int.tryParse(widget.id.toString()) ?? 0;
      request.fields['id'] =widget.id;

      // ✅ Attach the File
      request.files.add(await http.MultipartFile.fromPath(
        'attach',
        selectedFile!.path,
        filename: selectedFile!.path.split('/').last,

      ));

      // ✅ Send the Request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: $responseData");

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

        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context);
        });

      } else {
        throw Exception("Failed to upload: ${response.statusCode} - $responseData");
      }
    } catch (e) {
      print("Error Uploading File: $e");

      String errorMessage = "Failed to upload assignment";
      if (e is SocketException) {
        errorMessage = "No Internet connection. Please check your network.";
      } else if (e is FormatException) {
        errorMessage = "Unexpected server response. Please try again.";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));

    } finally {
      setState(() {
        isLoading = false; // Hide loader on error or success
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,

      appBar: AppBar(
        title: Text("Upload Assignment",
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
        ),
        backgroundColor: AppColors.secondary,
        iconTheme: IconThemeData(color: AppColors.textwhite,),
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
                  SizedBox(height: 20),



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
                        : Text("Upload Assignment", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),



                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSelectedFile(String label, IconData icon, VoidCallback onTap, bool fileSelected) {
    return selectedFile != null
        ? Card(
      elevation: 3,
      color: AppColors.textwhite,
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
                color: AppColors.textwhite,
                borderRadius: BorderRadius.circular(10)
            ),
            child: Center(child: Text("No file selected", style: TextStyle(color: Colors.grey)))),
      ),
    );
  }


}
