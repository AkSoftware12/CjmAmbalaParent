// import 'dart:convert';
//
//
// import 'package:avi/UI/Gallery/Video/video_player.dart';
//
// import '../../../constants.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import '../../../CommonCalling/data_not_found.dart';
// import '../../../CommonCalling/progressbarWhite.dart';
//
//
//
// class VideoAlbumListScreen extends StatefulWidget {
//   const VideoAlbumListScreen({super.key});
//
//   @override
//   State<VideoAlbumListScreen> createState() => _GalleryScreenState();
// }
//
// class _GalleryScreenState extends State<VideoAlbumListScreen> {
//
//   bool isLoading = false;
//   List<dynamic> images = []; // Declare a list to hold API data
//
//
//   @override
//   void initState() {
//     super.initState();
//     fetchSubjectData();
//     for (var image in images) {
//       precacheImage(NetworkImage(image['cover_image_url']), context);
//     }
//   }
//
//
//   Future<void> fetchSubjectData() async {
//     setState(() {
//       isLoading = true; // Show progress bar
//     });
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token');
//     print("Token: $token");
//
//     final response = await http.get(
//       Uri.parse(ApiRoutes.getVideos),
//       headers: {'Authorization': 'Bearer $token'},
//     );
//
//     if (response.statusCode == 200) {
//       final jsonResponse = json.decode(response.body);
//       setState(() {
//         images = jsonResponse['album'];
//         isLoading = false; // Stop progress bar
// // Update state with fetched data
//       });
//     } else {
//       setState(() {
//         isLoading = true; // Show progress bar
//       });
//     }
//   }
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return isLoading
//         ? WhiteCircularProgressWidget()
//         : images.isEmpty
//         ? Center(child: DataNotFoundWidget(title: 'Image  Not Available.',))
//         : GridView.builder(
//       padding:  EdgeInsets.all(0.sp),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         crossAxisSpacing: 0.0,
//         mainAxisSpacing: 0.0,
//       ),
//       itemCount: images.length,
//       cacheExtent: 1000,
//       shrinkWrap: true, // Fix overflow issue
//       physics: NeverScrollableScrollPhysics(),
//       itemBuilder: (context, index) {
//         return GestureDetector(
//           onTap: (){
//
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => VideoPlayer(
//                   url: images[index]['video_url'], title: '', videoId: null, videoStatus: '',
//                 ),
//               ),
//             );
//
//             // Navigator.push(
//             //   context,
//             //   MaterialPageRoute(
//             //     builder: (context) {
//             //       return VideoListScreen( data: images[index],);
//             //     },
//             //   ),
//             // );
//           },
//           child: Card(
//             color: Colors.white,
//             child: Padding(
//               padding:  EdgeInsets.all(1.sp),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: SizedBox(
//                       width: double.infinity,
//                       child: CachedNetworkImage(
//                         imageUrl: images[index]['cover_image_url'].toString(),
//                         fit: BoxFit.cover,
//                         height: 100.sp,
//                         placeholder: (context, url) => Center(child: CircularProgressIndicator()),
//                         errorWidget: (context, url, error) => SizedBox(
//                             width: double.infinity,
//                             child: Image.network('https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg?20200913095930',width: double.infinity,)
//                         ),
//                       ),
//                     ),
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(height: 4.h), // Spacing
//
//                       Text(
//                         images[index]['album_name'].toString(),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12.sp,
//                           color: Colors.black87,
//                         ),
//                       ),
//
//                       SizedBox(height:2.h),
//
//                       _buildInfoRow(Icons.calendar_today,
//                           'Event Date: ${images[index]['event_date']}'),
//
//                       _buildInfoRow(Icons.photo_library,
//                           'Total Photo(s): 5'),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//
//
//
//   }
//   // Reusable function for better spacing & icons
//   Widget _buildInfoRow(IconData icon, String text) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 0.h,horizontal: 0.h),
//       child: Row(
//         children: [
//           Icon(icon, size: 10.sp, color: Colors.blueAccent),
//           SizedBox(width: 3.w),
//           Expanded(
//             child: Text(
//               text,
//               style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
