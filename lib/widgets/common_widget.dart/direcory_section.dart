import 'package:aloo_sbji_mandi/screens/kishan/aloo_mitra_screen.dart';
import 'package:aloo_sbji_mandi/screens/directory_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DirectorySection extends StatelessWidget {
  final directoryItems;
  const DirectorySection({required this.directoryItems});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// TITLE ROW
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('directory'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            OutlinedButton(
              onPressed: () {
                // Navigate to Directory screen with filtered items
                final List<Map<String, dynamic>> items =
                    (directoryItems as List)
                        .map<Map<String, dynamic>>(
                          (item) => {
                            'image': item['image'] ?? '',
                            'titleKey': item['titleEn'] ?? item['title'] ?? '',
                            'route': item['route'] ?? '',
                          },
                        )
                        .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DirectoryScreen(customItems: items),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(50, 30),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: AppColors.primaryGreen),
              ),
              child: Text(
                tr('view_all').substring(0, 8),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// HORIZONTAL DIRECTORY CARDS
        SizedBox(
          height: 140,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final itemCount = directoryItems.length;

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = directoryItems[index];
                  final route = item['route'] ?? '';

                  return GestureDetector(
                    onTap: () {
                      if (route.isNotEmpty) {
                        // Navigate to AlooMitraScreen with the specific category filter
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AlooMitraScreen(initialCategory: route),
                          ),
                        );
                      }
                    },
                    child: SizedBox(
                      width: itemCount == 2
                          ? (screenWidth - 12) /
                                2 // 🔥 2 items → full width
                          : 120, // normal width for more items
                      child: _DirectoryCard(
                        image: item['image']!,
                        title: AppLocalizations.isHindi
                            ? item['title']!
                            : (item['titleEn'] ?? item['title']!),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

/// DIRECTORY CARD
// DIRECTORY CARD
class _DirectoryCard extends StatelessWidget {
  final String image;
  final String title;

  const _DirectoryCard({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 100,
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        color: Color(0xffDDFFB3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 80,
              width: 80,
              child: image.startsWith('http')
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Image.asset(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),

          // TITLE
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class NewsHowToSection extends StatelessWidget {
  const NewsHowToSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// NEWS SECTION
        _sectionHeader("News"),
        const SizedBox(height: 12),

        Row(
          children: const [
            Expanded(
              child: _ImageCard(image: "assets/1.png", title: ""),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ImageCard(image: "assets/2.png", title: ""),
            ),
          ],
        ),

        const SizedBox(height: 24),

        /// HOW TO SECTION
        _sectionHeader("How to-s?"),
        const SizedBox(height: 12),

        Row(
          children: const [
            Expanded(
              child: _ImageCard(image: "assets/11.png", title: ""),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ImageCard(image: "assets/21.png", title: ""),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// SECTION HEADER
  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: Size(50, 30),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide(color: AppColors.primaryGreen),
          ),
          child: Text(
            "View All",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }
}

/// IMAGE CARD WITH TEXT OVERLAY
class _ImageCard extends StatelessWidget {
  final String image;
  final String title;

  const _ImageCard({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
