import 'dart:async';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import '../HexColorCode/HexColor.dart';







class DocumentsScreen extends StatefulWidget {
  @override
  State<DocumentsScreen> createState() => _NewUserPaymentScreenState();
}

class _NewUserPaymentScreenState extends State<DocumentsScreen> {






  // Purana Code

  Map<String, dynamic>? studentData;
  bool isLoading = true;
  List<dynamic>? feesReceipt;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  @override
  void dispose() {

    super.dispose();
  }

















  Future<void> fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('newusertoken');
    print("token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfileNewUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        studentData = data['student'];
        feesReceipt = data['fees'];
        isLoading = false;
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
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: Text(
          'Documents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          // Card(
          //   // elevation: 4,
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: InkWell(
          //     onTap: () async {
          //       final Uri uri = Uri.parse(
          //         '${ApiRoutes.admissionDownload}${studentData!['id']}',
          //       );
          //       try {
          //         if (!await launchUrl(
          //           uri,
          //           mode: LaunchMode.externalApplication,
          //         )) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             SnackBar(content: Text('Could not open URL')),
          //           );
          //         }
          //       } catch (e) {
          //         ScaffoldMessenger.of(
          //           context,
          //         ).showSnackBar(SnackBar(content: Text('Error: $e')));
          //       }
          //     },
          //     borderRadius: BorderRadius.circular(12),
          //     child: Ink(
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           colors: [HexColor('61045F'), HexColor('AA076B')],
          //           begin: Alignment.topLeft,
          //           end: Alignment.bottomRight,
          //         ),
          //         borderRadius: BorderRadius.circular(12),
          //       ),
          //       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          //       child: Row(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Icon(Icons.print, color: Colors.white),
          //           SizedBox(width: 8),
          //           Text(
          //             'Admission Form Print',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 13.sp,
          //               fontWeight: FontWeight.w600,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),

      body: isLoading
          ? _buildShimmerLoading()
          : studentData == null
          ? _buildErrorUI()
          :
      Column(
        children: [

          SizedBox(
            width: double.infinity,
            height: 70.sp,
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Card(
                // elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () async {
                    final Uri uri = Uri.parse(
                      '${ApiRoutes.admissionDownload}${studentData!['id']}',
                    );
                    try {
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open URL')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [HexColor('61045F'), HexColor('AA076B')],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print, color: Colors.white,size: 25.sp,),
                        SizedBox(width: 8),
                        Text(
                          'Admission Form Print',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.download, color: Colors.white,size: 25.sp,),


                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: feesReceipt!.isEmpty
                ? Center(
              child: Text(
                'No fees receipt available',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            )
                :ListView.builder(
              itemCount: feesReceipt!.length,
              padding: EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final fee = feesReceipt![index];

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Padding(
                        padding: EdgeInsets.all(0.sp),
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(10)
                          ),

                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 0.w),
                            child: Row(
                              children: [
                                SizedBox(width: 5.w),

                                CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: Icon(
                                    Icons.payment,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      Text(
                                        double.parse(fee['amount']) < 1500
                                            ? 'Registration'
                                            : 'Admission',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.green,
                                        ),
                                      ),

                                      Text(
                                        '${fee['txn_date']??''}',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:  EdgeInsets.all(5.sp),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '₹ ${fee['amount'].toString()}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                          fontSize: 15.sp
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      ListTile(
                          title: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Padding(
                                padding:  EdgeInsets.all(0.sp),
                                child: Row(
                                  children: [
                                    Icon(Icons.account_circle,size: 15.sp,),
                                    SizedBox(width: 3.sp,),
                                    Text('${studentData!['name']??''}',style: TextStyle(color: Colors.black,fontSize: 14.sp,fontWeight: FontWeight.bold),),
                                  ],
                                ),
                              ),

                              Row(
                                children: [
                                  Icon(Icons.school,size: 15.sp,),
                                  SizedBox(width: 3.sp,),
                                  Text('${studentData!['class_name']??''}',style: TextStyle(color: Colors.black87,fontSize: 12.sp,fontWeight: FontWeight.bold),),
                                ],
                              ),
                              SizedBox(
                                height: 5.sp,
                              ),
                            ],
                          ),
                          subtitle: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fee['status'],
                                style: TextStyle(
                                  color: fee['status'] == 'SUCCESS'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          trailing:  IconButton(
                              onPressed: () async {
                                final Uri uri = Uri.parse('${ApiRoutes.newUserdownloadUrl}${fee['id']}');
                                try {
                                  if (!await launchUrl(uri,
                                      mode: LaunchMode.externalApplication)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open URL')),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },

                              icon:Icon(Icons.print))

                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(child: CupertinoActivityIndicator(radius: 20));
  }

  Widget _buildErrorUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 80.sp),
          SizedBox(height: 20.h),
          Text(
            "Error Loading Data",
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            "Unable to fetch payment details. Please try again.",
            style: TextStyle(fontSize: 16.sp, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}





