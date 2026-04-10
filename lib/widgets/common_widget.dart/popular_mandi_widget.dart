import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Popular mandis with their state and district mapping
const List<Map<String, String>> _popularMandis = [
  {'name': 'Agra', 'state': 'Uttar Pradesh', 'district': 'Agra', 'image': 'assets/popular_mandi.png'},
  {'name': 'Ahmedabad', 'state': 'Gujarat', 'district': 'Ahmedabad', 'image': 'assets/popular_mandi.png'},
  {'name': 'Delhi', 'state': 'Delhi', 'district': 'New Delhi', 'image': 'assets/popular_mandi.png'},
  {'name': 'Indore', 'state': 'Madhya Pradesh', 'district': 'Indore', 'image': 'assets/popular_mandi.png'},
];

Widget popularMandis({void Function(String state, String district)? onMandiTap}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Popular Mandis",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _popularMandis
              .map((m) => _MandiItem(
                    name: m['name']!,
                    image: m['image']!,
                    state: m['state']!,
                    district: m['district']!,
                    onTap: onMandiTap,
                  ))
              .toList(),
        ),
      ],
    ),
  );
}

class _MandiItem extends StatelessWidget {
  final String name;
  final String image;
  final String state;
  final String district;
  final void Function(String state, String district)? onTap;

  const _MandiItem({
    required this.name,
    required this.image,
    required this.state,
    required this.district,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!(state, district);
        } else {
          Navigator.pushNamed(context, '/city_mandi_price',
              arguments: {'state': state, 'district': district});
        }
      },
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              image,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
