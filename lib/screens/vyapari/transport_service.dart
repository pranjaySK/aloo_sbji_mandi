import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TransportServiceScreen extends StatefulWidget {
  const TransportServiceScreen({super.key});

  @override
  State<TransportServiceScreen> createState() => _TransportServiceScreenState();
}

class _TransportServiceScreenState extends State<TransportServiceScreen> {
  String? selectedState;
  String? selectedCity;
  List<String> availableCities = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(
          color: Colors.white, // icon color
        ),
        title: Text(
          "Transport Services",
          style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox(child: Image.asset("assets/backgroun2.png")),
          SingleChildScrollView(
            child: Column(
              children: [
                headerSection(),
                SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PopularServicesSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget headerSection() {
    return Stack(
      children: [
        SizedBox(height: 100),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(height: 50),
              _dropdown(
                hint: "Select State",
                value: selectedState,
                items: StateCityData.states,
                onChanged: (v) => setState(() {
                  selectedState = v;
                  selectedCity = null;
                  availableCities = v != null
                      ? StateCityData.getCitiesForState(v)
                      : [];
                }),
              ),
              const SizedBox(height: 12),
              _dropdown(
                hint: "Select City",
                value: selectedCity,
                items: availableCities,
                onChanged: (v) => setState(() => selectedCity = v),
              ),
              SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B7542),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/city_mandi_price');
                    },
                    child: Text(
                      "Search",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint, style: GoogleFonts.inter(color: AppColors.border)),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class PopularServicesSection extends StatelessWidget {
  const PopularServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          "Popular Services near you",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        ServiceCard(
          name: "SitaRam Transports",
          location: "Gurugram, Haryana",
          rating: 4.5,
          vehicles: 15,
          capacity: "3000 kg",
          rent: "₹550 per day",
        ),

        const SizedBox(height: 12),

        ServiceCard(
          name: "Narayana Transports",
          location: "Gurugram, Haryana",
          rating: 4.2,
          vehicles: 13,
          capacity: "3075 kg",
          rent: "₹670 per day",
        ),
      ],
    );
  }
}

class ServiceCard extends StatelessWidget {
  final String name;
  final String location;
  final double rating;
  final int vehicles;
  final String capacity;
  final String rent;

  const ServiceCard({
    super.key,
    required this.name,
    required this.location,
    required this.rating,
    required this.vehicles,
    required this.capacity,
    required this.rent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4B38A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Title + Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toString(), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            location,
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
          ),

          const SizedBox(height: 12),

          /// Details
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn(context, "Vehicles", vehicles.toString()),
              _infoColumn(context, "Capacity", capacity),
              _infoColumn(context, "Rent", rent),
            ],
          ),

          const SizedBox(height: 14),

          /// Contact Button
          Center(
            child: SizedBox(
              height: 36,
              width: 120,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B4D1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  "Contact",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(BuildContext context, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style:  GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
