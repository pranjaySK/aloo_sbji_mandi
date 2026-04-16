import 'package:flutter/material.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/kishan/aloo_mitra_screen.dart';

class DirectoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? customItems;

  const DirectoryScreen({super.key, this.customItems});

  static final List<Map<String, dynamic>> directoryItems = [
    {
      'image': 'assets/potato_seed.png',
      'titleKey': 'potato_seed_short',
      'route': 'potato-seeds',
    },
    {
      'image': 'assets/fertilizer.png',
      'titleKey': 'fertilizer_pesticides',
      'route': 'fertilizers',
    },
    {
      'image': 'assets/farming_labour.png',
      'titleKey': 'farming_labour',
      'route': 'majdoor',
    },
    {
      'image': 'assets/transport_service.png',
      'titleKey': 'transport_services',
      'route': 'transportation',
    },
    {
      'image': 'assets/gunny_bag.png',
      'titleKey': 'gunny_bags',
      'route': 'gunny-bag',
    },
    {
      'image': 'assets/hire_rent.png',
      'titleKey': 'farm_machinery',
      'route': 'machinery',
    },
  ];

  Widget directoryCard(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AlooMitraScreen(initialCategory: item['route']),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF81C784), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item['image'].toString().startsWith('http')
                  ? Image.network(
                      item['image'],
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      item['image'],
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              item['titleKey'] != null
                  ? AppLocalizations.tr(item['titleKey'])
                  : (AppLocalizations.isHindi
                        ? (item['title'] ?? '')
                        : (item['titleEn'] ?? item['title'] ?? '')),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = customItems ?? directoryItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0A5D1E),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.tr('directory'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0A5D1E),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0A5D1E)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return directoryCard(context, items[index]);
            },
          ),
        ),
      ),
    );
  }
}
