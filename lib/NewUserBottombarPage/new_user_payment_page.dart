import 'dart:async';
import 'package:avi/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cryptography/cryptography.dart';
import '../HexColorCode/HexColor.dart';
import '../strings.dart';
import '../utils/date_time_utils.dart';



// live key
const req_EncKey = '7ABE0A52322733FFDFE5285649F7B92D';
const req_Salt = '7ABE0A52322733FFDFE5285649F7B92D';
const res_DecKey = '66B7FF4DDA6F547C9CE1700440975C4A';
const res_Salt = '66B7FF4DDA6F547C9CE1700440975C4A';
const resHashKey = "3b9458ce3cd22c66f6";
const authUrl = "https://payment1.atomtech.in/ots/aipay/auth";

String? atomTokenId;
bool isLoading = false;

// Test Key
// const req_EncKey = 'A4476C2062FFA58980DC8F79EB6A799E';
// const req_Salt = 'A4476C2062FFA58980DC8F79EB6A799E';
// const res_DecKey = '75AEF0FA1B94B3C10D4F5B268F757F11';
// const res_Salt = '75AEF0FA1B94B3C10D4F5B268F757F11';
// const resHashKey = "KEYRESP123657234";
// const merchId = "317157";
// const merchPass = "Test@123";
// const prodId = "NSE";
// final authUrl = "https://paynetzuat.atomtech.in/ots/aipay/auth";
//
// String? atomTokenId;
// String currentTxnId = '';


final password = Uint8List.fromList(utf8.encode(req_EncKey));
final salt = Uint8List.fromList(utf8.encode(req_Salt));
final resPassword = Uint8List.fromList(utf8.encode(res_DecKey));
final resSalt = Uint8List.fromList(utf8.encode(res_Salt));
final iv =
Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

//Encrypt Function
Future<String> encrypt(String text) async {
  debugPrint('Input text for encryption: $text');
  try {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );

    final keyBytes = await derivedKey.extractBytes();
    debugPrint('Derived key bytes: $keyBytes');

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = await aesCbc.encrypt(
      utf8.encode(text),
      secretKey: SecretKey(keyBytes),
      nonce: iv,
    );

    final hexOutput = secretBox.cipherText
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    debugPrint('Encrypted hex output: $hexOutput');
    return hexOutput;
  } catch (e, stackTrace) {
    debugPrint('Encryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

// Decrypt Function
Future<String> decrypt(String hexCipherText) async {
  try {
    debugPrint('Input hex for decryption: $hexCipherText');

    // Convert hex string to bytes
    List<int> cipherText = [];
    for (int i = 0; i < hexCipherText.length; i += 2) {
      String hex = hexCipherText.substring(i, i + 2);
      cipherText.add(int.parse(hex, radix: 16));
    }
    debugPrint('Cipher text bytes: $cipherText');

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(resPassword),
      nonce: resSalt, // Use the same salt as in encryption
    );

    final keyBytes = await derivedKey.extractBytes();

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: iv, // Use the same IV as in encryption
      mac: Mac.empty,
    );
    debugPrint('SecretBox: $secretBox');

    final decryptedBytes = await aesCbc.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );

    final decryptedText = utf8.decode(decryptedBytes);
    debugPrint('Decrypted text: $decryptedText');
    return decryptedText;
  } catch (e, stackTrace) {
    debugPrint('Decryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

Future<bool> validateSignature(
    Map<String, dynamic> data, String resHashKey) async {
  debugPrint("validateSignature called");

  String signatureString = data["payInstrument"]["merchDetails"]["merchId"]
      .toString() +
      data["payInstrument"]["payDetails"]["atomTxnId"].toString() +
      data['payInstrument']['merchDetails']['merchTxnId'].toString() +
      data['payInstrument']['payDetails']['totalAmount'].toStringAsFixed(2) +
      data['payInstrument']['responseDetails']['statusCode'].toString() +
      data['payInstrument']['payModeSpecificData']['subChannel'][0].toString() +
      data['payInstrument']['payModeSpecificData']['bankDetails']['bankTxnId']
          .toString();

  var bytes = utf8.encode(signatureString);
  var key = utf8.encode(resHashKey);

  final hmac = Hmac.sha512();
  final secretKey = SecretKey(key);
  final mac = await hmac.calculateMac(bytes, secretKey: secretKey);

  var genSig =
  mac.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  if (data['payInstrument']['payDetails']['signature'] == genSig) {
    print("ignaure matched");
    return true;
  } else {
    print("signaure does not matched");
    return false;
  }
}


class NewUserPaymentScreen extends StatefulWidget {
  @override
  State<NewUserPaymentScreen> createState() => _NewUserPaymentScreenState();
}

class _NewUserPaymentScreenState extends State<NewUserPaymentScreen> {
  String createOrderId = ""; //optional
  String productId = ""; //optional
  bool isButtonDisabled = false;
  Timer? _timer;
  int remainingSeconds = 0;

  static const String disableTimeKey = 'pay_button_disabled_time';
  static const int cooldownMinutes = 1;

  Timer? _statusCheckTimer; // Timer for checking fee status

  String? fullResponse; // New variable to store the full response
  String? apiResponseStatus; // Stores the status of the API call
  String? transactionStatus;





  // Purana Code

  Map<String, dynamic>? studentData;
  bool isLoading = true;
  List<dynamic>? feesReceipt;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
    checkCooldownStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }
  void startCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(disableTimeKey, currentTime);

    setState(() {
      isButtonDisabled = true;
      remainingSeconds = cooldownMinutes * 60;
    });

    startTimer();
  }
  void checkCooldownStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final disabledAt = prefs.getInt(disableTimeKey);

    if (disabledAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - disabledAt;
      final elapsedSeconds = diff ~/ 1000;
      final totalCooldown = cooldownMinutes * 60;

      if (elapsedSeconds < totalCooldown) {
        setState(() {
          isButtonDisabled = true;
          remainingSeconds = totalCooldown - elapsedSeconds;
        });
        startTimer();
      } else {
        await prefs.remove(disableTimeKey);
      }
    }
  }
  void startTimer() async {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {
        _timer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(disableTimeKey);
        setState(() {
          isButtonDisabled = false;
        });
      }
    });
  }
  // Start the periodic status check when payment is initiated
  void startStatusCheck() {
    _statusCheckTimer?.cancel(); // Cancel any existing timer
    _statusCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      // checkFeeStatus();
    });
  }

  void _showCooldownDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      // Allow dialog to be dismissed by tapping outside
      builder: (BuildContext context) {
        return _CooldownDialog(remainingSeconds: remainingSeconds);
      },
    );
  }
  Future<void> orderCreate(BuildContext context) async {
    showLoadingDialog(context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");
    final url = Uri.parse(ApiRoutes.orderCreateNewUser);
    Map<String, dynamic> body = {
      "amount": studentData!['admission_fees'],
      "student_id": studentData?['unique_id'].toString(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Adding token here
        },
        body: jsonEncode(body),
      );


      if (response.statusCode == 200) {
        print("Success: ${response.body}");
        Map<String, dynamic> data = jsonDecode(response.body);

        setState(() {
          createOrderId = data["order_id"]; // ✅ Correct assignment
          productId = data["product_id"]; // ✅ Correct assignment
          print('OrderId: $createOrderId');
          print('productId: $productId');
        });

        initiatePayment();

        startStatusCheck(); // Start checking status after payment initiation
      } else {
        print("Failed: ${response.statusCode}, Response: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User manually dialog close na kar sake
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15.sp),
              Text("Please wait...")
            ],
          ),
        );
      },
    );
  }

  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }



  Future<void> sendResponseToApi(String response) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('newusertoken');
    print("Token: $token");
    final url = Uri.parse(ApiRoutes.payFeesNewUser);
    Map<String, dynamic> body = {
      "data": response, // transactionData is the JSON string
    };
    try {
      final apiResponse = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",

          // Add any additional headers (e.g., Authorization) if required
        },
        body: jsonEncode(body),
      );

      if (apiResponse.statusCode == 200) {
        setState(() {
          apiResponseStatus = "API Call Successful";
        });
        _showPaymentSuccessDialog(context);

      } else {
        _showPaymentCanceledDialog(context);
        throw Exception('API call failed with status: ${apiResponse.statusCode}');
      }
    } catch (e) {
      setState(() {
        apiResponseStatus = "API Call Failed: $e";
      });
      _showPaymentCanceledDialog(context);

    }
  }
  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Payment Successful',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your payment has been processed successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {
                    fetchProfileData();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentCanceledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Transaction Failed',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your transaction has been Failed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {

                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }


 // Live Key

  Future<void>initiatePayment() async {
    setState(() {
      isLoading = true;
      // currentTxnId = 'Invoice${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    });

    try {
      final String txnDate = DateTime.now().toString().split('.')[0];
      const String amount = "1";
      const String userEmailId = "test.user@atomtech.in";
      const String userContactNo = "8888888888";

      //Json data for sending to atom server
      String jsonData = '{"payInstrument":{"headDetails":{"version":"OTSv1.1","api":"AUTH","platform":"FLASH"},"merchDetails":{"merchId":"712303","userId":"712303","password":"4139f20c","merchTxnId":"$createOrderId","merchTxnDate":"$txnDate"},"payDetails":{"amount":"${studentData!['admission_fees']}","product":"$productId","custAccNo":"639827","txnCurrency":"INR"},"custDetails":{"custEmail":"${studentData!['email'].toString()}","custMobile":"${studentData!['contact'].toString()}"},  "extras": {"udf1":"${studentData?['unique_id'].toString()}","udf2":"$createOrderId","udf3":"","udf4":"udf4","udf5":"udf5"}}}';

      final String encDataR = await encrypt(jsonData);
      final response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: {
          'encData': encDataR,
          'merchId': '712303',
        },
      );

      if (response.statusCode == 200) {
        debugPrint("Response received: Status code 200");

        final responseData = response.body.split('&');
        debugPrint("Response body split into array: $responseData");

        if (responseData.length > 1) {
          // Extract the encrypted data
          final encDataPart = responseData
              .firstWhere((element) => element.startsWith('encData'));
          final encryptedData = encDataPart.split('=')[1];
          final extractedData = ['encData', encryptedData];
          debugPrint("Extracted encrypted response data: $extractedData");

          try {
            // Decrypt the extracted data
            final decryptedData = await decrypt(extractedData[1]);
            debugPrint("Decrypted data: $decryptedData");

            final jsonResponse = json.decode(decryptedData);
            debugPrint("JSON response: $jsonResponse");
            hideLoadingDialog(context);


            if (jsonResponse['responseDetails']['txnStatusCode'] == 'OTS0000') {
              setState(()  async {
                atomTokenId = jsonResponse['atomTokenId'].toString();

                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PaymentWebView(
                          atomTokenId:
                          jsonResponse['atomTokenId'].toString(),
                          merchId: '712303',
                          currentTxnId: createOrderId,
                          onReturn: _refresh,
                          userEmail: studentData!['email'].toString(),
                          userContact:
                          studentData!['contact'].toString(),
                        )));


                if (result != null) {
                  setState(() {
                    // Expect result to be a Map with status and response
                    if (result is Map<String, dynamic>) {
                      transactionStatus = result['status'] as String;
                      if (result['status'] == "Transaction Success") {
                        fullResponse = result['response'] as String;
                        sendResponseToApi(fullResponse!);

                      }
                    }
                  });
                }
                isLoading = false;
                // ignore: prefer_interpolation_to_compose_strings
                debugPrint("Transaction Status Code: " +
                    jsonResponse['responseDetails']['txnStatusCode']);
              });
            } else {
              debugPrint("Error: txnStatusCode is not 'OTS0000'");
              throw Exception('Payment initialization failed');
            }
          } catch (e) {
            debugPrint("Decryption failed: $e");
            throw Exception('Error during decryption: $e');
          }
        } else {
          debugPrint("Error: Invalid response data format");
          throw Exception('Invalid response data format');
        }
      } else {
        debugPrint(
            "Error: Failed to connect to the server. Status code: ${response.statusCode}");
        throw Exception('Failed to connect to the server');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // showError('Payment initialization failed: $e');
    }
  }





  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  void _refresh() {
    setState(() {
      fetchProfileData();
    });
  }

  String formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
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
          " Fees",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
      ),
      body: isLoading
          ? _buildShimmerLoading()
          : studentData == null
          ? _buildErrorUI()
          :
      // studentData!['admission_fees_paid'] == 1
      Column(
        children: [
           if(studentData!['admission_fees'] !=0)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20.sp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.payment,
                            color: AppColors.secondary,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Admission Fees",
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "One-time payment for admission",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "₹${studentData!['admission_fees'] ?? 'N/A'}",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 50.h),

                    (studentData!['admission_fees_paid'] !=1)?
                    SizedBox(
                      width: double.infinity,
                      height: 42.h,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (isButtonDisabled) {
                            // Show dialog when timer is running
                            _showCooldownDialog(context);
                          } else {
                            // orderCreate(context);
                            // startCooldown();

                            onPayNow();

                          }
                        },

                        label: Text(
                          isButtonDisabled
                              ? 'Please wait (${formatDuration(remainingSeconds)})'
                              : 'Pay ₹ ${studentData!['admission_fees']}',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ):
                    SizedBox(
                      width: double.infinity,
                      height: 42.h,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check_circle , // Show a filled check icon for paid state
                          color: Colors.white,
                          size: 20,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                               Colors.green, // Green background for paid state
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        label: Text('Fees Paid',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ), onPressed: () {
                        _showAlreadyPaidDialog(context,);
                      },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding:  EdgeInsets.all(12.sp),
              child: Text('Fees Receipt',style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),),
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
                                  // '${fee['txn_date']??''}',
                                  AppDateTimeUtils.date( fee['txn_date']??''),
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
                              Row(
                                children: [
                                  Icon(Icons.account_circle,size: 15.sp,),
                                  SizedBox(width: 3.sp,),
                                  Text('${studentData!['name']??''} / ${studentData!['class_name']??''}',style: TextStyle(color: Colors.black,fontSize: 14.sp,fontWeight: FontWeight.bold),),
                                ],
                              ),
                              SizedBox(
                                height: 5.sp,
                              )
                              // Row(
                              //   children: [
                              //     Icon(Icons.shopping_cart,size: 15.sp,),
                              //     SizedBox(width: 3.sp,),
                              //     Text(fee['order_id']??'',style: TextStyle(color: Colors.grey,fontSize: 14.sp,fontWeight: FontWeight.bold),),
                              //   ],
                              // ),
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

  void _showAlreadyPaidDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeIn,
                  ),
                ),
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 16,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.green.shade50],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info Icon with Animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green.shade600,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          'Payment Already Completed',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        // Content
                        Text(
                          'Your fees of ₹${studentData!['admission_fees']} have already been paid!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Confirmation Message
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.shade200, width: 1.5),
                          ),
                          child: Text(
                            'No further payment is required.',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // OK Button
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade500, Colors.green.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade400.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'OK',
                                style: GoogleFonts.montserrat(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ));
        },
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

  Future<bool> showPremiumTermsDialog(BuildContext context) async {
    bool isChecked = false;
    bool showError = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              backgroundColor: Colors.black,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 1,
                      )
                    ],
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // TITLE
                      Center(
                        child: Text(
                          "Terms & Conditions",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // SCROLLABLE AREA
                      Container(
                        height: 330,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            overscroll: true,
                            scrollbars: true,
                          ),
                          child: SingleChildScrollView(
                            // physics: const BouncingScrollPhysics(),
                            child: Text(
                              AppStrings.termsText,
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // CHECKBOX
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            activeColor: Colors.green,
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            onChanged: (val) {
                              setState(() {
                                isChecked = val!;
                                showError = false; // checkbox tick hote hi error hata do
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              "I agree to the Terms & Conditions",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13.5,
                              ),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 5),

// ----------------------
// INLINE ERROR MESSAGE
// ----------------------
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            "⚠️ Please accept Terms & Conditions",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 6),

// BUTTON ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (!isChecked) {
                                setState(() {
                                  showError = true; // yahi par error dikhana hai
                                });
                                return;
                              }

                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Accept & Continue",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ) ??
        false;
  }
  void onPayNow() async {
    bool accepted = await showPremiumTermsDialog(context);

    if (accepted) {
      orderCreate(context);
      startCooldown();
    }
  }
}


class _CooldownDialog extends StatefulWidget {
  final int remainingSeconds;

  const _CooldownDialog({required this.remainingSeconds});

  @override
  _CooldownDialogState createState() => _CooldownDialogState();
}

class _CooldownDialogState extends State<_CooldownDialog> {
  late int _currentSeconds;
  Timer? _dialogTimer;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.remainingSeconds;
    _startTimer();
  }

  void _startTimer() {
    _dialogTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() {
          _currentSeconds--;
        });
      } else {
        _dialogTimer?.cancel();
        Navigator.pop(
            context); // Automatically close the dialog when time is up
      }
    });
  }

  @override
  void dispose() {
    _dialogTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      title: Text(
        'Payment on Cooldown',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.orange,
            size: 50.sp,
          ),
          SizedBox(height: 10.sp),
          Text(
            'Please wait for ${_formatDuration(_currentSeconds)} before you can make another payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog manually
          },
          child: Text(
            'OK',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}


class PaymentWebView extends StatefulWidget {
  final String atomTokenId;
  final String merchId;
  final String currentTxnId;
  final VoidCallback onReturn;
  final String userEmail;
  final String userContact;

  const PaymentWebView({
    required this.atomTokenId,
    required this.merchId,
    required this.currentTxnId,
    required this.onReturn,
    required this.userEmail,
    required this.userContact,
    super.key,
  });

  @override
  State createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  double progress = 0;
  late InAppWebViewController webViewController;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleBackButtonAction(context),
      child: Scaffold(
        backgroundColor: HexColor('#3c2365'),
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 40.sp),
              child: InAppWebView(
                  initialData: InAppWebViewInitialData(

                    data: '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://psa.atomtech.in/staticdata/ots/js/atomcheckout.js"></script>
      </head>
      <body>
      <script>
          function initPayment() {
            const options = {
              "atomTokenId": "${widget.atomTokenId}",
              "merchId": "${widget.merchId}",
              "custEmail": "${widget.userEmail}",
              "custMobile": "${widget.userContact}",
              "returnUrl": "https://payment.atomtech.in/mobilesdk/param",
              "userAgent": "mobile_webView"
            };
            new AtomPaynetz(options, 'uat');
          }
          window.onload = initPayment;
        </script>
      </body>
      </html>
      ''',
                  ),
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    debugPrint("shouldOverrideUrlLoading called");
                    var uri = navigationAction.request.url!;

                    if (["upi", "tez", "gpay", "phonepe", "paytmmp", "credpay"]
                        .any(uri.scheme.contains)) {
                      debugPrint("UPI URL detected");
                      await launchUrl(uri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                  ),

                onLoadStop: (controller, url) async {
                  print("onLoadStop");
                  print(url);
                  setState(() {
                    progress = 1.0;
                  });
// Check for returnUrl
                  if (url.toString().contains("returnUrl")) {
                    print("returnUrl detected");
                    _closeWebView(context, {
                      'status': 'Cancel',
                      'response': '',
                    });
                    return; // Exit after closing WebView
                  }

                  if (url != null &&
                      url.toString().contains("/mobilesdk/param")) {
                    print("/mobilesdk/param detected");

                    final String response = await controller.evaluateJavascript(
                        source:
                        "document.getElementsByTagName('h5')[0].innerHTML");
                    debugPrint("HTML response : $response");

                    final split = response.trim().split('|');
                    final Map<int, String> values = {
                      for (int i = 0; i < split.length; i++) i: split[i]
                    };

                    var transactionResult = "";
                    String? decryptedResponseData; // Store the decrypted response

                    if (response.trim().contains("cancelTransaction")) {
                      transactionResult = "Transaction Cancelled!";
                    } else {
                      final splitTwo = values[1]!.split('=');
                      print("encData value");
                      debugPrint(splitTwo[1].toString());

                      decryptedResponseData = await decrypt(splitTwo[1].toString());
                      debugPrint('Decrypted response data: $decryptedResponseData');

                      Map<String, dynamic> jsonInput =
                      jsonDecode(decryptedResponseData);
                      debugPrint("Reading full response: $jsonInput");

                      var checkFinalTransaction =
                      await validateSignature(jsonInput, resHashKey);

                      debugPrint("Signature matched: $checkFinalTransaction");

                      if (checkFinalTransaction) {
                        print("Signature is valid");
                        if (jsonInput["payInstrument"]["responseDetails"]
                        ["statusCode"] ==
                            'OTS0000') {
                          debugPrint("Transaction success and close");
                          transactionResult = "Transaction Success";
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Transaction Successful!"),
                              duration: Duration(seconds: 3),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          debugPrint("Transaction failed");
                          transactionResult = "Transaction Failed";
                        }
                      } else {
                        debugPrint("Signature mismatched");
                        transactionResult = "Signature Failed";
                      }
                    }
                    // Return both status and full response
                    _closeWebView(context, {
                      'status': transactionResult,
                      'response': decryptedResponseData,
                    });
                  }
                },

            ),
            )
          ],
        ),
      ),
    );
  }

  void _closeWebView(BuildContext context, Map<String, dynamic> result) {
    debugPrint("Closing web");
    debugPrint("result: $result");
    if (!mounted) return;
    Navigator.of(context).pop(result); // Return result map
  }


  void _showPaymentErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Payment Error',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<bool> _handleBackButtonAction(BuildContext context) async {
    debugPrint("_handleBackButtonAction called");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Do you want to exit the payment?'),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
              _showPaymentCanceledDialog(context);
              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              //   content: Text("Transaction Status = Transaction cancelled"),
              // ));
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return Future.value(true);
  }

  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Payment Successful',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your payment has been processed successfully!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentCanceledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Transaction Cancelled',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your transaction has been cancelled.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {

                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }


}



