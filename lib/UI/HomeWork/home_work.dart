import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../HexColorCode/HexColor.dart';
import '../../constants.dart';
import '../Assignment/upload_assignments.dart';
import '../Auth/login_screen.dart';
import 'package:html/parser.dart' as html_parser;

class HomeWorkScreen extends StatefulWidget {
  final String title;
  const HomeWorkScreen({super.key, required this.title});

  @override
  State<HomeWorkScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<HomeWorkScreen> {
  bool isLoading = false;
  List assignments = []; // Declare a list to hold API data

  @override
  void initState() {
    super.initState();

    DateTime.now().subtract(const Duration(days: 30));

    fetchAssignmentsData();
  }

  Future<void> fetchAssignmentsData() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getAssignments),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        assignments = jsonResponse['data']; // Update state with fetched data
        isLoading = false; // Stop progress bar

      });
    } else {
      _showLoginDialog();
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Please log in again to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }
  void _refresh() {
    setState(() {
      fetchAssignmentsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          iconTheme: IconThemeData(color: AppColors.textwhite),
          backgroundColor: AppColors.secondary,
          title: Text(
            widget.title,
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
          )),
      body:  isLoading
          ? WhiteCircularProgressWidget()
          : assignments.isEmpty
          ? Center(child: DataNotFoundWidget(title: 'Home Work  Not Available.',))
          :  ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            String description = html_parser.parse(assignment['description']).body?.text ?? '';
            String startDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(assignment['start_date']));
            String endDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(assignment['due_date']));

            return Card(
              margin: EdgeInsets.all(5),
              elevation: 4,
              color: AppColors.secondary,
              shadowColor: Colors.redAccent,


              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Colors.grey, // Border color
                  width: 1,          // Border width
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                  color: AppColors.textwhite,
                                  borderRadius: BorderRadius.circular(25)
                              ),
                              child: Center(
                                child: Text('${index+1}',
                                  style: GoogleFonts.montserrat(
                                    textStyle: Theme.of(context).textTheme.displayLarge,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    color: AppColors.textblack,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [


                                Text(
                                  assignment['title'].toString().toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    textStyle: Theme.of(context).textTheme.displayLarge,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.normal,
                                    color: AppColors.textwhite,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  width: MediaQuery.of(context).size.width*0.4,
                                  child: Text(
                                    '${description}'.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis, // Add ellipsis for overflow
                                    style: GoogleFonts.montserrat(
                                      textStyle: Theme.of(context).textTheme.displayLarge,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.normal,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'Start : ${startDate}',
                              style: GoogleFonts.montserrat(
                                textStyle: Theme.of(context).textTheme.displayLarge,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.normal,
                                color: AppColors.textwhite,
                              ),
                            ),
                            Text(
                              'Due : ${endDate}',
                              style: GoogleFonts.montserrat(
                                textStyle: Theme.of(context).textTheme.displayLarge,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.normal,
                                color: AppColors.textwhite,
                              ),
                            ),
                          ],
                        )



                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                            onTap: () async {
                              final Uri pdfUri = Uri.parse(assignment['attach'].toString());
                              if (await canLaunchUrl(pdfUri)) {
                                await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
                              } else {
                                print("Could not launch $pdfUri");
                              }

                              // if (await canLaunchUrl(Uri.parse(assignment['attach'].toString()))) {
                              // await launchUrl(Uri.parse(assignment['attach'].toString()));
                              // } else {
                              // throw 'Could not launch ${assignment['attach']}';
                              // }
                            },
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                color:Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white, // You can change the color as needed
                                  width: 1,
                                ),
                              ),
                              child:  Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    'View'.toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      textStyle: Theme.of(context).textTheme.displayLarge,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.normal,
                                      color: AppColors.textwhite,
                                    ),
                                  ),
                                ),
                              ),
                            )

                        ),

                        GestureDetector(
                            onTap: (){
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>  AssignmentUploadScreen(onReturn: _refresh, id: assignment['id'].toString(),)),
                              );
                            },
                            child:Container(
                              width: 100,
                              decoration: BoxDecoration(
                                color:Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white, // You can change the color as needed
                                  width: 1,
                                ),
                              ),
                              child:  Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    'UPLOAD',
                                    style: GoogleFonts.montserrat(
                                      textStyle: Theme.of(context).textTheme.displayLarge,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.normal,
                                      color: AppColors.textwhite,
                                    ),
                                  ),
                                ),
                              ),
                            )

                        ),
                        Center(
                            child:      Container(
                              width: 100,
                              decoration: BoxDecoration(
                                color:assignment['attendance_status']=='submitted'?Colors.green:HexColor('#780606'),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.textwhite, // You can change the color as needed
                                  width: 1,
                                ),
                              ),
                              child:  Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    assignment['attendance_status'].toString().toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      textStyle: Theme.of(context).textTheme.displayLarge,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.normal,
                                      color: AppColors.textwhite,
                                    ),
                                  ),
                                ),
                              ),
                            )

                        ),



                      ],
                    ),


                  ],
                ),
              ),
            );
          },
        ),


    );
  }
}
