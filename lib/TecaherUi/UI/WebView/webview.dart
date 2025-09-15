// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
//
// import '../../../constants.dart';
//
//
// class WebViewExample extends StatefulWidget {
//   final String title;
//   final String url;
//   const WebViewExample({super.key, required this.title, required this.url});
//
//   @override
//   _WebViewExampleState createState() => _WebViewExampleState();
// }
//
// class _WebViewExampleState extends State<WebViewExample> {
//   late WebViewController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//
//
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onProgress: (int progress) {
//             // Update loading bar.
//           },
//           onPageStarted: (String url) {},
//           onPageFinished: (String url) {},
//           onHttpError: (HttpResponseError error) {},
//           onWebResourceError: (WebResourceError error) {},
//           onNavigationRequest: (NavigationRequest request) {
//             if (request.url.startsWith(widget.url)) {
//               return NavigationDecision.prevent;
//             }
//             return NavigationDecision.navigate;
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse(widget.url));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: AppColors2.primary,
//         iconTheme: IconThemeData(color: Colors.black),
//         title: Text(widget.title,style: TextStyle(color: Colors.black),),
//       ),
//       body:  WebViewWidget(controller: _controller),
//
//     );
//   }
// }
