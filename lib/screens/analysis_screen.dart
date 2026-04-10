import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
    int selectedIndex = 0; // 0=Yield, 1=Soil, 2=Weather
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
        appBar: CustomRoundedAppBar(
     
        title: "Crop Analysis",
       
      ),

      // appBar: AppBar(
      //   backgroundColor: const Color(0xFF0B6623),
      //   title: const Text("Analysis"),
      //   centerTitle: true,
      //   elevation: 0,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionTitle("Market Trends"),
            _chartCard(height: 180),

            const SizedBox(height: 16),
            _sectionTitle("Crop Analysis"),
            _cropAnalysisTabs(),
          _chartCardByTab(),


            const SizedBox(height: 16),
            _sectionTitle("Market News"),
            _newsCard(
              text:
                  "The potato market continues to grow steadily due to high demand.",
            ),
            _newsCard(
              text:
                  "AI predicts stable prices with gradual increase in coming weeks.",
            ),

            const SizedBox(height: 16),
            _sectionTitle("AI Predictions"),
            _pricePredictionCard(),

            const SizedBox(height: 20),
            _sectionTitle("AI Insights"),
_aiInsightsCard(),

          ],
        ),
      ),
    );
  }

  // ---------------- WIDGETS ----------------
  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

 Widget _chartCard({required double height, String title = "Graph"}) {
  return Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: Text(
      title,
      style: GoogleFonts.inter(color: Colors.grey),
    ),
  );
}


 Widget _cropAnalysisTabs() {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        _tabChip("Current Yield", 0),
        _tabChip("Soil Conditions", 1),
        _tabChip("Weather", 2),
      ],
    ),
  );
}

  Widget _tabChip(String text, int index) {
  final bool isSelected = selectedIndex == index;

  return GestureDetector(
    onTap: () {
      setState(() {
        selectedIndex = index;
      });
    },
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF0B6623)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    ),
  );
}

  Widget _newsCard({required String text}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13),
      ),
    );
  }

  Widget _pricePredictionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            "₹ 75 / kg",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Expected Increase",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
 Widget _chartCardByTab() {
  if (selectedIndex == 0) {
    return _chartCard(height: 160, title: "Yield Chart");
  } else if (selectedIndex == 1) {
    return _chartCard(height: 160, title: "Soil Chart");
  } else {
    return _chartCard(height: 160, title: "Weather Chart");
  }
}

Widget _aiInsightsCard() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      "• AI & Market Prediction trends indicate stable pricing.\n\n"
      "• Demand remains high due to increased consumption.\n\n"
      "• Weather conditions are favorable for harvest.\n\n"
      "• Storage quality will play a key role in price stability.",
      style: GoogleFonts.inter(
        fontSize: 12,
        height: 1.5,
      ),
    ),
  );
}


}
