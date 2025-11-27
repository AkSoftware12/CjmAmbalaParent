// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';
//
// class VideoPlayer extends StatefulWidget {
//   final String url;
//   final String title;
//   final int? videoId;
//   final String videoStatus; // "locked" or "unlocked"
//
//   const VideoPlayer({
//     super.key,
//     required this.url,
//     required this.title,
//     required this.videoId,
//     required this.videoStatus,
//   });
//
//   @override
//   State<VideoPlayer> createState() => _VideoPlayerYoutubeState();
// }
//
// class _VideoPlayerYoutubeState extends State<VideoPlayer> {
//   late YoutubePlayerController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = YoutubePlayerController(
//       initialVideoId: YoutubePlayer.convertUrlToId(widget.url)!,
//       flags: const YoutubePlayerFlags(
//         autoPlay: true,
//         mute: false,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Check if the device is in landscape orientation.
//     bool isLandscape = MediaQuery
//         .of(context)
//         .orientation == Orientation.landscape;
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // The video player is at the center.
//           Center(
//             child: YoutubePlayerBuilder(
//               player: YoutubePlayer(
//                 controller: _controller,
//                 showVideoProgressIndicator: true,
//                 progressIndicatorColor: Colors.red,
//               ),
//               builder: (context, player) {
//                 return player;
//               },
//             ),
//           ),
//           // If in landscape, overlay a back button on top of the player.
//             if (isLandscape)
//               Positioned(
//                 top: 20,
//                 left: 10,
//                 child: SafeArea(
//                   child: IconButton(
//                     icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
//                     onPressed: () async {
//                       // Set the device orientation to portrait before navigating back.
//                       await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//                       Navigator.pop(context);
//                     },
//                   ),
//                 ),
//               ),
//           // In portrait mode, show an AppBar at the top.
//           if (!isLandscape)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: AppBar(
//                 backgroundColor: Colors.black,
//                 iconTheme: const IconThemeData(color: Colors.white),
//                 title: const Text(
//                     'Video', style: TextStyle(color: Colors.white)),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
