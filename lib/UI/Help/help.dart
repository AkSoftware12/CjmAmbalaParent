import 'dart:convert';
import 'dart:io';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';



class HelpScreen extends StatefulWidget {
  final String appBar;
  const HelpScreen({super.key, required this.appBar});

  @override
  State<HelpScreen> createState() => _DoubtSessionState();
}

class _DoubtSessionState extends State<HelpScreen> {



  // Message text controller
  final TextEditingController messageController = TextEditingController();






  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar.isEmpty
          ? null
          :  AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title:  Text("Help",
          style: GoogleFonts.radioCanada(
            textStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
          ),

        ),
      ),



      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                // height: 150.sp,
                width: double.infinity,
                child: Opacity(
                  opacity: 0.1, // Adjust the opacity value (0.0 to 1.0)
                  child: Image.asset(AppAssets.logo),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Message input field
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Enter your message',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                  ),


                  const SizedBox(height: 16),

                ],
              ),
            ),
          ],
        ),
      ),

      bottomSheet: Container(
        height: 80,
        color: Colors.white,
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Spacer(),

                Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: GestureDetector(
                    onTap: (){
                    },
                    child: Row(
                      children: [
                        Container(
                          // width: double.infinity,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10), // Adjust the radius to make it more or less rounded
                            color: AppColors.primary, // Set your desired color
                          ),

                          child: Center(
                            child: Padding(
                              padding:  EdgeInsets.only(left: 35,right: 35),
                              child: Text('Send',
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.white),
                                ),),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Spacer(),

              ],
            ),
          ],
        ),

      ),

    );
  }
}
