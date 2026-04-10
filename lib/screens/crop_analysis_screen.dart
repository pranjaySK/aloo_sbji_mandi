import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CropAnalysisScreen extends StatelessWidget {
  const CropAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
    appBar: CustomRoundedAppBar(
      
        title: "Crop Analysis",
        
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCropImage(),
            const SizedBox(height: 16),
            _buildChartCard(title: "Current Yield"),
            const SizedBox(height: 16),
            _buildChartCard(title: "Soil Conditions"),
            const SizedBox(height: 16),
            _buildWeatherCard(),
            const SizedBox(height: 16),
            _buildChartCard(title: "Harvest Forecast"),
                        const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text("*AI harvest forecasts show normal yield expectations this season, indicating favorable conditions for planned harvesting and storage, with minimal risk of early supply pressure.",style: GoogleFonts.inter(fontSize: 13,fontWeight: FontWeight.w500,color: AppColors.blackColor)),
            ),
               Align(
                          alignment: Alignment.bottomRight,
                          child: 
                          
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            ),
                            onPressed: () {
                               Navigator.pushNamed(context,  '/create_availability');
                            },
                            child:  Text("Done",style: GoogleFonts.inter(fontSize: 16,fontWeight: FontWeight.w700,color: AppColors.buttonTextColor),),
                          ),
                        )
          ],
        ),
      ),
    );
  }
    Widget _buildCropImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        "assets/crop_img.png", // replace with your image
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
  Widget _buildChartCard({required String title}) {
    return
     Column(
      crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 15),
         Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      dashArray: [4, 4],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _barGroups(),
              ),
            ),
          ),
             ),
       ],
     );
  
  }
  Widget _buildWeatherCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
                    "Weather Forecasting",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
          SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  const SizedBox(height: 8),
                  Text("19°C",style: GoogleFonts.inter(fontSize: 18,fontWeight: FontWeight.w500)),
                   Text("City, State",style: GoogleFonts.inter(fontSize: 14,fontWeight: FontWeight.w500)),
                   Text("Air Quality: 264",style: GoogleFonts.inter(fontSize: 14,fontWeight: FontWeight.w500)),
                   Text("Very Low Pollen Count",style: GoogleFonts.inter(fontSize: 14,fontWeight: FontWeight.w500)),
                ],
              ),
              Image.asset("assets/weather.png",height: 50,width: 50)
              // const Icon(Icons.wb_sunny, color: Colors.orange, size: 40),
            ],
          ),
        ),
      ],
    );
  }
  
  List<BarChartGroupData> _barGroups() {
    final values = [25, 80, 18, 35, 82, 52, 85, 15];

    return List.generate(values.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: values[index].toDouble(),
            width: 22,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            color: const Color(0xFF356E3D),
          ),
        ],
      );
    });
  }

}

