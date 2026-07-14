import 'dart:convert';
import 'dart:io';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/VacanciesScreen/vacancies_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../splash_sreen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'constants.dart';
// import '../screens/notification_screen.dart'; // ⬅️ ADDED - apni screen ka import yaha do

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  Platform.isAndroid
      ? await Firebase.initializeApp(
    options: kIsWeb || Platform.isAndroid
        ? const FirebaseOptions(
      apiKey: 'AIzaSyBhuh_2exvng2cYi1-WVG8AWFGFgLjRYQM',
      appId: '1:1012918033516:android:0b6718b40f48b55cb84c49',
      messagingSenderId: '1012918033516',
      projectId: 'cjm-ambala',
      storageBucket: "cjm-ambala.firebasestorage.app",
    )
        : null,
  )
      : await Firebase.initializeApp();
  NotificationService.initNotifications();
  FirebaseMessaging.instance.getToken().then((token) {});
  // Portrait Only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(ProviderScope(child: MyApp(navigatorKey: navigatorKey)));

  // runApp(const MyApp());
  // Wait 5 seconds then show update dialog
  // await Future.delayed(Duration(seconds: 5));
  // UpdateChecker.checkForUpdate(navigatorKey.currentContext!);
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      // Use builder only if you need to use library outside ScreenUtilInit context
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey, // ⬅️ Add this
          home: SplashScreen(),
        );
      },
    );
  }
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
  AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  // ⬅️ ADDED - Backend se aaya pura data print karne ke liye common function
  static void _printMessageData(String source, RemoteMessage message) {
    if (kDebugMode) {
      print("📩 ================ $source ================");
      print("Title: ${message.notification?.title}");
      print("Body: ${message.notification?.body}");
      print("Data (backend se): ${message.data}");
      print("Full data JSON: ${jsonEncode(message.data)}");
      print("MessageId: ${message.messageId}");
      print("SentTime: ${message.sentTime}");
      print("=================================================");
    }
  }

  /// Initialize notifications
  static Future<void> initNotifications() async {
    await Firebase.initializeApp();

    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print("✅ Push Notifications Enabled");
      }

      await _initLocalNotifications();

      // iOS foreground notification settings
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // ✅ Topic subscription - sabhi users ko 'all_users' topic pe subscribe karo
      try {
        await _firebaseMessaging.subscribeToTopic('all_users');
        if (kDebugMode) {
          print("✅ Subscribed to topic: all_users");
        }
      } catch (e) {
        if (kDebugMode) {
          print("❌ Topic subscribe error: $e");
        }
      }

      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print("FCM Token: $token");
      }

      // Foreground
      FirebaseMessaging.onMessage.listen(_onMessage);

      // App opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Background/terminated
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // ⬅️ ADDED - App terminated thi, notification tap se open hui
      RemoteMessage? initialMessage =
      await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        // ⬅️ ADDED - Terminated state se open hone pe data print karo
        _printMessageData("APP OPENED FROM TERMINATED", initialMessage);

        Future.delayed(const Duration(seconds: 5), () {
          _handleNavigation(initialMessage.data);
        });
      }
    }
  }

  // ⬅️ ADDED - Common navigation handler
  static void _handleNavigation(Map<String, dynamic> data) {
    if (kDebugMode) {
      print("🧭 Navigating with data: $data");
    }

    if (navigatorKey.currentState == null) {
      if (kDebugMode) {
        print("❌ Navigator not ready yet");
      }
      return;
    }

    final String? type = data['type']?.toString();

    switch (type) {
      case 'vacancy':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const VacanciesScreen(), // ⬅️ apni screen daalo
          ),
        );
        break;

      default:
        break;
    }
  }

  /// Foreground notification
  static void _onMessage(RemoteMessage message) {
    // ⬅️ ADDED - Foreground me backend ka data print karo
    _printMessageData("FOREGROUND NOTIFICATION", message);

    // Foreground me local notification dikha do
    _showLocalNotification(message);
  }

  /// Notification click
  static void _onMessageOpenedApp(RemoteMessage message) {
    // ⬅️ ADDED - Notification tap pe backend ka data print karo
    _printMessageData("NOTIFICATION CLICKED (BACKGROUND)", message);

    _handleNavigation(message.data); // ⬅️ ADDED
  }

  /// Background message handler
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {
    await Firebase.initializeApp();

    // ⬅️ ADDED - Background me backend ka data print karo
    if (kDebugMode) {
      print("🌙 ============ BACKGROUND NOTIFICATION ============");
      print("Title: ${message.notification?.title}");
      print("Body: ${message.notification?.body}");
      print("Data (backend se): ${message.data}");
      print("==================================================");
    }
  }

  /// Init local notifications
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('👆 Local notification tapped');
          print('Notification payload: ${response.payload}');
        }
        // ⬅️ ADDED - Foreground local notification tap pe navigation
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data =
            jsonDecode(response.payload!) as Map<String, dynamic>;

            // ⬅️ ADDED - Decoded data print karo
            if (kDebugMode) {
              print('Decoded data (backend se): $data');
            }

            _handleNavigation(data);
          } catch (e) {
            if (kDebugMode) {
              print('❌ Payload decode error: $e');
            }
          }
        }
      },
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Show local notification with full text
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title ??
            message.data['title']?.toString() ??
            'Notification';

    final String body =
        message.notification?.body ??
            message.data['body']?.toString() ??
            '';

    final BigTextStyleInformation bigTextStyleInformation =
    BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: 'Tap to open',
      htmlFormatSummaryText: false,
    );

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker',
      styleInformation: bigTextStyleInformation,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
}