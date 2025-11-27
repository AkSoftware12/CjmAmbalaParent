import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../constants.dart';


class FaqScreen extends StatefulWidget {
  final String appBar;

  const FaqScreen({super.key, required this.appBar});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final List<Map<String, String>> faqData = [
    {
      "question": "What types of quizzes are available on the app?",
      "answer":
      "Our app offers a variety of quizzes, including Mock Tests, Test Series, Daily Quizzes, and Practice Tests. Each type is designed to help you improve in specific areas and track your progress effectively.",
    },
    {
      "question": "How do I start a quiz?",
      "answer":
      "To start a quiz, go to the Quizzes section, select the type of quiz you're interested in, and choose a specific quiz from the list. Then, click on the Start Quiz button to begin.",
    },
    {
      "question": "How are scores calculated?",
      "answer":
      "Scores are calculated based on correct answers, with negative marking applied to incorrect answers where applicable. Your overall performance score is also calculated using a weighted formula across mock tests, test series, quizzes, and practice questions.",
    },
    {
      "question": "Where can I see my subject combination?",
      "answer":
      "Your chosen subject combination is saved in your profile, and you can view or modify it in the Subject Selection section.",
    },
    {
      "question":
      "Your chosen subject combination is saved in your profile, and you can view or modify it in the Subject Selection section.",
      "answer":
      "The overall performance score is a weighted average based on mock tests (30%), test series (20%), daily quizzes (20%), practice questions (20%), and app activity (10%). The score is capped at 80% to maintain fair grading.",
    }
  ];


  List<dynamic> faqlist = [];




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
        backgroundColor: AppColors2.primary,
        iconTheme: IconThemeData(color: Colors.black),
        title:  Text("FAQ",
          style: GoogleFonts.radioCanada(
            textStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),

        ),
      ),


      body: Stack(
        children: [
          // Center(
          //   child: SizedBox(
          //     child: Opacity(
          //       opacity: 0.1, // Adjust the opacity value (0.0 to 1.0)
          //       child: Image.asset(AppAssets.logo),
          //     ),
          //   ),
          // ),

          ListView.builder(
            itemCount: faqData.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.blueGrey.shade50,
                child: ExpansionTile(
                  title: Text(
                    faqData[index]['question']!,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Container(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(faqData[index]['answer']!,
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                                color: Colors.black),
                          ),),
                      ),
                    ),
                  ],
                  trailing: Icon(Icons.arrow_drop_down), // Arrow icon
                  initiallyExpanded: index == 0,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


