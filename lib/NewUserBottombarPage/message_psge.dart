import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../utils/SupportPage16/html.dart';



class MessageListScreen extends StatefulWidget {
  final String appbar;
  const MessageListScreen({super.key, required this.appbar});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  // final List<Map<String, String>> messages = [
  //   {
  //     'name': 'Alice',
  //     'message': 'Hey! I hope you re doing well. I just wanted to check in and see how things are going on your end. It s been a while since we last spoke, and I thought it would be a good idea to catch up. Things have been a bit hectic here with work and some personal projects I’ve been trying to complete. I’ve been learning a lot about time management lately, and its helping me balance things better. By the way, I finally started reading that book you recommended last month — its fantastic! The writing style is so engaging, and I find myself highlighting something on almost every page. I’d love to hear your thoughts on it once I’m done. Also, I was thinking it would be great to meet up sometime soon. Maybe this weekend if youre free? We can grab a coffee or lunch, just like old times. Let me know what works best for you. I really miss our random conversations and the good laughs. Anyway, no rush — reply when you get the chance. Take care of yourself and stay safe. Looking forward to hearing from you soon!',
  //     'time': '10:30 AM',
  //   },
  //   {
  //     'name': 'Bob',
  //     'message': 'Did you check the file I sent yesterday? Let me know your feedback.',
  //     'time': '10:45 AM',
  //   },
  //   {
  //     'name': 'Charlie',
  //     'message': 'Let\'s meet tomorrow at 5 PM to discuss further.',
  //     'time': '11:00 AM',
  //   },
  //   {
  //     'name': 'Daisy',
  //     'message': 'I sent the documents you requested. Please confirm.',
  //     'time': '11:20 AM',
  //   },
  // ];

  List<dynamic>? messages;

  Map<String, dynamic>? studentData;

  bool isLoading = true;


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
        messages = data['messages']; // 👈 assign here
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
        title: Text('Messages',
          style: TextStyle(
              color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold
          ),
        ),
        leading:widget.appbar==''? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // पिछले स्क्रीन पर वापस जाएं
          },
        ):null,
        backgroundColor: AppColors.secondary,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:  isLoading
          ? _buildShimmerLoading()
          : messages == null || messages!.isEmpty
          ? Center(child: Text("No messages found.",style: TextStyle(color: Colors.white,fontSize: 15.sp),))
          : ListView.builder(
        itemCount: messages!.length,
        itemBuilder: (context, index) {
          final msg = messages![index];
          String formatDateTime(String dateTimeStr) {
            try {
              DateTime dateTime = DateTime.parse(dateTimeStr).toLocal();
              String day = dateTime.day.toString().padLeft(2, '0');
              String month = dateTime.month.toString().padLeft(2, '0');
              String year = dateTime.year.toString();
              String hour = dateTime.hour.toString().padLeft(2, '0');
              String minute = dateTime.minute.toString().padLeft(2, '0');

              return '$day-$month-$year $hour:$minute';
            } catch (e) {
              return '';
            }
          }

          return Card(
            color: Colors.white,
            elevation: 5,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:AppColors.secondary,
                foregroundColor: Colors.white,
                child: Text(msg['title']![0]),
              ),
              title: Text(msg['title']!,
                style:  TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.textblack),
              ),

              subtitle: Text(
                formatDateTime(msg['updated_at'] ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              trailing: Icon(CupertinoIcons.right_chevron,color: Colors.black,),
              onTap: () async {
                try {
                  // Token load from SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('newusertoken');

                  if (token == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Token not found, please login again")),
                    );
                    return;
                  }

                  // API URL
                  const String apiUrl = ApiRoutes.msgMarkSeenNewUser;

                  // API Body
                  final body = {
                    "message_id": msg['id'].toString(),
                  };

                  // API Call
                  final response = await http.post(
                    Uri.parse(apiUrl),
                    headers: {
                      "Content-Type": "application/json",
                      "Authorization": "Bearer $token",
                    },
                    body: jsonEncode(body),
                  );

                  if (response.statusCode == 200) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessageDetailScreen(
                          name: msg['title']!,
                          message: msg['message']!,
                          time:  formatDateTime(msg['updated_at'] ?? ''),
                        ),
                      ),
                    );

                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessageDetailScreen(
                          name: msg['title']!,
                          message: msg['message']!,
                          time:  formatDateTime(msg['updated_at'] ?? '')!,
                        ),
                      ),
                    );

                  }
                } catch (e) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessageDetailScreen(
                        name: msg['title']!,
                        message: msg['message']!,
                        time:  formatDateTime(msg['updated_at'] ?? '')!,
                      ),
                    ),
                  );

                }

              },
            ),
          );
        },
      ),
    );



  }





  Widget _buildShimmerLoading() {
    return Center(
      child: CupertinoActivityIndicator(radius: 20),
    );
  }
}

class MessageDetailScreen extends StatelessWidget {
  final String name;
  final String message;
  final String time;

  MessageDetailScreen({
    required this.name,
    required this.message,
    required this.time,
  });
  final staticAnchorKey = GlobalKey();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(name,
          style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold
          ),
        ),
        backgroundColor: AppColors.secondary,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding:  EdgeInsets.all(13.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sent at: $time", style: TextStyle(color: AppColors.secondary,fontWeight: FontWeight.bold,fontSize: 16.sp)),
              const SizedBox(height: 20),
              CustomHtmlView(
                html: message ?? '',

              ),


              // Text(
              //   message,
              //   style: GoogleFonts.openSans(
              //     fontSize: 15.sp,
              //     fontWeight: FontWeight.w500,
              //     color: Colors.black87,
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
