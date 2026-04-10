import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateAvailabilityScreen extends StatelessWidget {
  const CreateAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(
          color: Colors.white, // icon color
        ),

        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create Availability",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Details",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            _CustomTextField(hint: "Owner’s Name"),
            const SizedBox(height: 12),

            _CustomTextField(
              hint: "Owner’s Phone Number",
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),

            _CustomTextField(hint: "Storage Location"),
            const SizedBox(height: 12),

            _CustomTextField(
              hint: "Minimum Rent Price",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            /// Upload Image Box
            _UploadBox(),

            const SizedBox(height: 24),

            /// Done Button
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/create_availability');
                },
                child: Text(
                  "Done",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.buttonTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final String hint;
  final TextInputType keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _CustomTextField({
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1B48C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1B48C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B5D1E)),
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 206, 204, 204),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: DottedBorder(
          options: RectDottedBorderOptions(
            color: const Color.fromARGB(255, 109, 108, 108),
            strokeWidth: 2,
            dashPattern: [6, 4],
          ),
          // 👈 yahi main cheez hai
          // color: Colors.grey,
          // strokeWidth: 1,
          // dashPattern: const [6, 4], // dot/dash size
          // borderType: BorderType.RRect,
          // radius: const Radius.circular(12),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
            height: 70,
            width: 220,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Upload Storage Pictures",
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                SizedBox(height: 6),
                Icon(Icons.add, size: 20, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
