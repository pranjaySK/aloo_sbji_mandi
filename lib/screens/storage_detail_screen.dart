import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StorageDetailScreen extends StatelessWidget {
  const StorageDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: CustomRoundedAppBar(
  
    title: "Kartar Store",
    actions: const [
      Icon(Icons.star, color: Colors.amber, size: 16),
       Text("4.5", style: TextStyle(fontSize: 13,color: Colors.white))
    ],
  ),
  //     appBar: AppBar(
  //       backgroundColor: AppColors.primaryGreen,
  //       iconTheme: const IconThemeData(
  //   color: Colors.white, // icon color
  // ),
       
     
      
  //       title:  Text(
  //         "Kartar Store",
  //         style: GoogleFonts.inter(fontWeight: FontWeight.w600,color: Colors.white),
  //       ),
  //       actions: const [
  //         Padding(
  //           padding: EdgeInsets.only(right: 12),
  //           child: Row(
  //             children: [
  //               Icon(Icons.star, color: Colors.amber, size: 16),
  //               SizedBox(width: 4),
  //               Text("4.5", style: TextStyle(fontSize: 13,color: Colors.white)),
  //             ],
  //           ),
  //         )
  //       ],
  //     ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// Images
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ImageCard("assets/cloud.png"),
                  const SizedBox(width: 12),
                  _ImageCard("assets/cloud.png"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// Details
             Center(
              child: Text(
                "Details",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _detailText(context, "Owned By", "Sanjeet Karter"),
            _detailText(context, "Rent Price", "₹ 530 per day"),
            _detailText(context, "Storage Capacity", "XX"),
            _detailText(context, "Location", "Gurugram, Haryana"),
            _detailText(context, "Contact number", "+91 9876543210"),

            const SizedBox(height: 24),

            /// Buttons
             PrimaryButton(text: "Call", onTap: (){

             }),
            // Pr(
            //   text: "",
            //   onTap: () {},
            // ),
            const SizedBox(height: 12),
             PrimaryButton(text: "Chat", onTap: (){

             })
            // _ActionButton(
            //   text: "Chat",
            //   onTap: () {},
            // ),
          ],
        ),
      ),
    );
  }

  Widget _detailText(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
          children: [
            TextSpan(
              text: "$title:  ",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
            TextSpan(text: value, style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),),
          ],
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String image;

  const _ImageCard(this.image);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        image,
        width: 200,
        height: 140,
        fit: BoxFit.cover,
      ),
    );
  }
}


// ignore: unused_element
class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ActionButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0B5D1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

