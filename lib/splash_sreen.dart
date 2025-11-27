import 'dart:async';
import 'package:avi/NewUserBottombarPage/new_user_bottombar_page.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'TecaherUi/UI/bottom_navigation.dart';
import 'UI/Auth/login_screen.dart';
import 'UI/bottom_navigation.dart';



class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    postRequestWithToken();
    _checkConnectivity();
  }

  Future<void> postRequestWithToken() async {
    try {
      final response = await http.get(Uri.parse(ApiRoutes.clear));

      if (!mounted) return; // Check before updating state

      if (response.statusCode == 200) {
        setState(() {
          print('Api Hit');
        });
      } else {
        print('Failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? newUsertoken = prefs.getString('newusertoken');
    String? teacherToken = prefs.getString('teachertoken');
    final connectivityResult = await Connectivity().checkConnectivity();

    if (!mounted) return; // Check before using setState or Navigator

    if (connectivityResult == ConnectivityResult.none) {
      setState(() => _isConnected = false);
      _showNoInternetDialog();
    } else {
      setState(() => _isConnected = true);

      if (token != null && token.isNotEmpty) {
        print('CheckToken:$token');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BottomNavBarScreen(initialIndex: 0)),
        );
      } else if (newUsertoken != null && newUsertoken.isNotEmpty) {
        print('CheckNewToken:$newUsertoken');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => NewUserBottombarPage()),
        );
      } else if (teacherToken != null && teacherToken.isNotEmpty) {
        print('CheckNTeacherToken:$teacherToken');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherBottomNavBarScreen(initialIndex: 0,),
          ),
        );

      }

      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  // Show Cupertino dialog when there's no internet
  void _showNoInternetDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text('Please check your internet connection and try again.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Reload'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _checkConnectivity(); // Retry connectivity check
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background, // Moved color inside decoration
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(10), // Optional: Add some padding inside the container
          child: _isConnected
              ? Image.asset(
            AppAssets.cjmlogo,
            width: MediaQuery.of(context).size.width * 0.5, // Responsive width
            height: MediaQuery.of(context).size.height * 0.25, // Responsive height
            fit: BoxFit.contain,
          )
              : const CircularProgressIndicator(), // Show loading spinner if not connected
        ),
      ),
    );
  }
}
