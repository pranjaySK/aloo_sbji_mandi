import 'dart:convert';
import 'dart:typed_data';

import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';
import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AlooMitraScreen extends StatefulWidget {
  final String? initialCategory;

  const AlooMitraScreen({super.key, this.initialCategory});

  @override
  State<AlooMitraScreen> createState() => _AlooMitraScreenState();
}

class _AlooMitraScreenState extends State<AlooMitraScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  List<dynamic> _alooMitras = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'all';

  // Location filter state
  bool _nearbyOnly = false;
  String _userVillage = '';
  String _userDistrict = '';
  String _userState = '';
  final String _filterState = '';
  final String _filterDistrict = '';
  final String _filterVillage = '';

  // Dropdown filter state
  String? _selectedState;
  String? _selectedCity;
  List<String> _availableCities = [];

  final List<Map<String, dynamic>> _categories = [
    {'value': 'all', 'labelEn': 'All', 'labelHi': 'सभी', 'icon': Icons.people},
    {
      'value': 'potato-seeds',
      'labelEn': 'Potato Seeds',
      'labelHi': 'आलू का बीज',
      'icon': Icons.grass,
    },
    {
      'value': 'fertilizers',
      'labelEn': 'Fertilizers',
      'labelHi': 'खाद/दवाई',
      'icon': Icons.eco,
    },
    {
      'value': 'machinery',
      'labelEn': 'Machinery',
      'labelHi': 'मशीनरी',
      'icon': Icons.agriculture,
    },
    {
      'value': 'transportation',
      'labelEn': 'Transport',
      'labelHi': 'परिवहन',
      'icon': Icons.local_shipping,
    },
    {
      'value': 'gunny-bag',
      'labelEn': 'Gunny Bag',
      'labelHi': 'बारदाना',
      'icon': Icons.inventory_2,
    },
    {
      'value': 'majdoor',
      'labelEn': 'Majdoor',
      'labelHi': 'मजदूर',
      'icon': Icons.engineering,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Find initial tab index based on initialCategory
    int initialIndex = 0;
    if (widget.initialCategory != null) {
      for (int i = 0; i < _categories.length; i++) {
        if (_categories[i]['value'] == widget.initialCategory) {
          initialIndex = i;
          _selectedCategory = widget.initialCategory!;
          break;
        }
      }
    }

    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _categories[_tabController.index]['value'];
        });
        _fetchAlooMitras();
      }
    });
    _loadUserAddress();
    _fetchAlooMitras();
  }

  Future<void> _loadUserAddress() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        final address = user['address'] ?? {};
        setState(() {
          _userVillage = address['village'] ?? '';
          _userDistrict = address['district'] ?? '';
          _userState = address['state'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user address: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAlooMitras() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Build query parameters
      final queryParams = <String, String>{};

      if (_selectedCategory != 'all') {
        if (_selectedCategory == 'machinery') {
          queryParams['serviceType'] = 'machinery-rent';
        } else {
          queryParams['serviceType'] = _selectedCategory;
        }
      }

      // Apply dropdown location filters only when NOT in nearby mode
      if (!_nearbyOnly) {
        if (_selectedState != null && _selectedState!.isNotEmpty) {
          queryParams['state'] = _selectedState!;
        }
        if (_selectedCity != null && _selectedCity!.isNotEmpty) {
          queryParams['district'] = _selectedCity!;
        }
      }

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/user/aloo-mitras',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> results = data['data'] ?? [];

        // Client-side nearby filtering: match provider's village/district
        // with farmer's village/district
        if (_nearbyOnly) {
          final farmerVillage = _userVillage.toLowerCase().trim();
          final farmerDistrict = _userDistrict.toLowerCase().trim();

          results = results.where((mitra) {
            final addr = mitra['address'] ?? {};
            final providerVillage = (addr['village'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            final providerDistrict = (addr['district'] ?? '')
                .toString()
                .toLowerCase()
                .trim();

            // Match if village or district matches the farmer's
            if (farmerVillage.isNotEmpty &&
                providerVillage.isNotEmpty &&
                providerVillage == farmerVillage) {
              return true;
            }
            if (farmerDistrict.isNotEmpty &&
                providerDistrict.isNotEmpty &&
                providerDistrict == farmerDistrict) {
              return true;
            }
            return false;
          }).toList();
        }

        setState(() {
          _alooMitras = results;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load service providers';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(Map<String, dynamic> mitra) async {
    final mitraId = mitra['_id'];
    if (mitraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('service_provider_not_found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    try {
      // Connect to socket first
      await _chatService.connectSocket();

      // Get or create conversation
      final conversationId = await _chatService.getOrCreateConversation(
        mitraId,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Create ChatUser from mitra data
        final alooMitraProfile = mitra['alooMitraProfile'] ?? {};
        final businessName = alooMitraProfile['businessName'] ?? '';
        final firstName = businessName.isNotEmpty
            ? businessName
            : (mitra['firstName'] ?? '');

        final chatUser = ChatUser(
          id: mitraId,
          firstName: firstName,
          lastName: businessName.isNotEmpty ? '' : (mitra['lastName'] ?? ''),
          role: 'aloo-mitra',
          phone: mitra['phone'],
        );

        // Navigate to chat detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversationId,
              otherUser: chatUser,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        String errorMessage = e.toString();
        // Clean up error message
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception:', '').trim();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('chat_start_failed')),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: tr('retry'),
              textColor: Colors.white,
              onPressed: () => _startChat(mitra),
            ),
          ),
        );
        debugPrint('Chat error: $e');
      }
    }
  }

  void _showMitraDetails(Map<String, dynamic> mitra) {
    final firstName = mitra['firstName'] ?? '';
    final lastName = mitra['lastName'] ?? '';
    final phone = mitra['phone'] ?? '';
    final alooMitraProfile = mitra['alooMitraProfile'] ?? {};
    final serviceType = alooMitraProfile['serviceType'] ?? mitra['subRole'];
    final businessName = alooMitraProfile['businessName'] ?? '';
    final businessAddress = alooMitraProfile['businessAddress'] ?? '';
    final businessPincode = alooMitraProfile['businessPincode'] ?? '';
    final businessLocation = alooMitraProfile['businessLocation'];
    final description = alooMitraProfile['description'] ?? '';
    final address = mitra['address'] ?? {};
    final village = address['village'] ?? '';
    final district = address['district'] ?? '';
    final state = address['state'] ?? '';
    final pincode = address['pincode'] ?? '';
    final List<dynamic> businessPhotos =
        alooMitraProfile['businessPhotos'] ?? [];

    // Check if has location coordinates
    final hasLocation =
        businessLocation != null &&
        businessLocation['latitude'] != null &&
        businessLocation['longitude'] != null;

    final displayName = businessName.isNotEmpty
        ? businessName
        : '$firstName $lastName'.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with icon and name
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.cardGreen,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getSubRoleIcon(serviceType),
                        color: AppColors.primaryGreen,
                        size: 35,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getSubRoleLabel(serviceType),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description if available
                if (description.isNotEmpty) ...[
                  _buildInfoSection(
                    tr('details'),
                    description,
                    Icons.info_outline,
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact info
                if (phone.isNotEmpty)
                  _buildInfoSection(tr('phone_number'), phone, Icons.phone),
                const SizedBox(height: 16),

                // Business Address (for fertilizers)
                if (businessAddress.isNotEmpty) ...[
                  _buildInfoSection(
                    tr('shop_address'),
                    businessPincode.isNotEmpty
                        ? '$businessAddress - $businessPincode'
                        : businessAddress,
                    Icons.store,
                  ),
                  const SizedBox(height: 16),
                ],

                // Business Location Map Link (for fertilizers with location)
                if (hasLocation) ...[
                  _buildLocationMapSection(
                    businessLocation['latitude'],
                    businessLocation['longitude'],
                  ),
                  const SizedBox(height: 16),
                ],

                // Address
                if (village.isNotEmpty ||
                    district.isNotEmpty ||
                    state.isNotEmpty) ...[
                  _buildInfoSection(
                    tr('location'),
                    [
                      village,
                      district,
                      state,
                      pincode,
                    ].where((e) => e.isNotEmpty).join(', '),
                    Icons.location_on,
                  ),
                  const SizedBox(height: 16),
                ],

                // Business Photos Slider
                if (businessPhotos.isNotEmpty) ...[
                  Text(
                    tr('business_photos'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoSlider(businessPhotos, height: 180),
                  const SizedBox(height: 12),
                ],

                // Call & Chat buttons
                Row(
                  children: [
                    // Call button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final phone = mitra['phone']?.toString() ?? '';
                          if (phone.isNotEmpty) {
                            Navigator.pop(context); // Close bottom sheet
                            launchUrl(Uri.parse('tel:$phone'));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('phone_not_available')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.call, color: Colors.white),
                        label: Text(
                          tr('call_btn'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Chat button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close bottom sheet
                          _startChat(mitra);
                        },
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: Text(
                          tr('chat'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationMapSection(double latitude, double longitude) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('shop_location'),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final url =
                'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
            final uri = Uri.parse(url);

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('open_in_maps'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('click_to_see_shop_location'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: Colors.blue[700], size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenPhoto(BuildContext context, String photoData) {
    Uint8List? bytes;
    try {
      final base64Str = photoData.contains(',')
          ? photoData.split(',').last
          : photoData;
      bytes = base64Decode(base64Str);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 60,
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSlider(List<dynamic> photos, {double height = 150}) {
    final pageNotifier = ValueNotifier<int>(0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: height,
            child: PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => pageNotifier.value = i,
              itemBuilder: (context, index) {
                final photoData = photos[index].toString();
                return GestureDetector(
                  onTap: () => _showFullScreenPhoto(context, photoData),
                  child: _buildPhotoImage(photoData, fit: BoxFit.cover),
                );
              },
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: pageNotifier,
            builder: (_, current, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                photos.length,
                (i) => Container(
                  width: i == current ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.primaryGreen
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoImage(
    String photoData, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    // Handle network URLs (Cloudinary etc.)
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      return Image.network(
        photoData,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Icon(Icons.image, color: Colors.grey[400]),
        ),
      );
    }

    try {
      final base64Str = photoData.contains(',')
          ? photoData.split(',').last
          : photoData;
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Icon(Icons.image, color: Colors.grey[400]),
        ),
      );
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: Icon(Icons.image, color: Colors.grey[400]),
      );
    }
  }

  String _getSubRoleLabel(String? subRole) {
    if (subRole == null) return '';

    // Map service type values to labels
    final serviceLabels = {
      'potato-seeds': tr('potato_seeds'),
      'fertilizers': tr('fertilizers'),
      'machinery-rent': tr('machinery_rent'),
      'transportation': tr('transportation'),
      'gunny-bag': tr('gunny_bag'),
      'majdoor': tr('majdoor'),
    };

    return serviceLabels[subRole] ?? subRole;
  }

  IconData _getSubRoleIcon(String? subRole) {
    final serviceIcons = {
      'potato-seeds': Icons.grass,
      'fertilizers': Icons.eco,
      'machinery-rent': Icons.agriculture,
      'transportation': Icons.local_shipping,
      'gunny-bag': Icons.inventory_2,
      'majdoor': Icons.engineering,
    };

    return serviceIcons[subRole] ?? Icons.person;
  }

  String _getCategoryTitle() {
    if (widget.initialCategory == null || widget.initialCategory == 'all') {
      return tr('service_provider');
    }

    final titles = {
      'potato-seeds': tr('potato_seeds'),
      'fertilizers': tr('fertilizers'),
      'machinery': tr('machinery_rent'),
      'transportation': tr('transportation'),
      'gunny-bag': tr('gunny_bag'),
      'majdoor': tr('majdoor'),
    };

    return titles[widget.initialCategory] ?? tr('service_provider');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          _getCategoryTitle(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        // Only show tabs when no specific category is passed (user opened from "Aloo Mitra" or "All")
        bottom: widget.initialCategory == null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                tabs: _categories.map((cat) {
                  return Tab(
                    child: Row(
                      children: [
                        Icon(cat['icon'], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.isHindi
                              ? cat['labelHi'] as String
                              : cat['labelEn'] as String,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Location filter bar
          _buildLocationFilterBar(),
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchAlooMitras,
                          child: Text(tr('retry')),
                        ),
                      ],
                    ),
                  )
                : _alooMitras.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nearbyOnly
                              ? (AppLocalizations.isHindi
                                    ? 'आपके आस-पास कोई सेवा प्रदाता नहीं मिला'
                                    : 'No nearby service provider found')
                              : (AppLocalizations.isHindi
                                    ? 'इस श्रेणी में कोई सेवा प्रदाता नहीं मिला'
                                    : 'No service provider found in this category'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_nearbyOnly && _userDistrict.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.isHindi
                                ? '📍 $_userDistrict, $_userState'
                                : '📍 $_userDistrict, $_userState',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        if (_nearbyOnly) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _nearbyOnly = false);
                              _fetchAlooMitras();
                            },
                            icon: const Icon(Icons.public, size: 18),
                            label: Text(tr('show_all')),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchAlooMitras,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alooMitras.length,
                      itemBuilder: (context, index) {
                        final mitra = _alooMitras[index];
                        return _buildMitraCard(mitra);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilterBar() {
    final hasUserLocation = _userVillage.isNotEmpty || _userDistrict.isNotEmpty;

    return Container(
      color: AppColors.primaryGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // State & City dropdowns side by side
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                // State dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedState,
                    hint: Text(
                      tr('select_state'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    isExpanded: true,
                    items: StateCityData.states
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedState = v;
                        _selectedCity = null;
                        _availableCities = v != null
                            ? StateCityData.getCitiesForState(v)
                            : [];
                        _nearbyOnly = false;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // City dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    hint: Text(
                      tr('select_city'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    isExpanded: true,
                    items: _availableCities
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedCity = v;
                        _nearbyOnly = false;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Full-width Search button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBg(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() => _nearbyOnly = false);
                  _fetchAlooMitras();
                },
                child: Text(
                  tr('search'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
          // Nearby providers section
          if (hasUserLocation)
            Container(
              width: double.infinity,
              color: AppColors.cardBg(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _nearbyOnly = !_nearbyOnly;
                    if (_nearbyOnly) {
                      _selectedState = null;
                      _selectedCity = null;
                      _availableCities = [];
                    }
                  });
                  _fetchAlooMitras();
                },
                child: Text(
                  _nearbyOnly
                      ? (AppLocalizations.isHindi
                            ? '📍 आस-पास के प्रदाता: ${[_userVillage, _userDistrict].where((e) => e.isNotEmpty).join(', ')}'
                            : '📍 Nearby: ${[_userVillage, _userDistrict].where((e) => e.isNotEmpty).join(', ')}')
                      : (AppLocalizations.isHindi
                            ? '📍 आस-पास के प्रदाता दिखाएं'
                            : '📍 Show nearby providers'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _nearbyOnly
                        ? AppColors.primaryGreen
                        : Colors.grey[700],
                    decoration: _nearbyOnly ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          if (!hasUserLocation) const SizedBox.shrink(),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildMitraCard(Map<String, dynamic> mitra) {
    final firstName = mitra['firstName'] ?? '';
    final lastName = mitra['lastName'] ?? '';
    // Get service type from alooMitraProfile
    final alooMitraProfile = mitra['alooMitraProfile'] ?? {};
    final serviceType = alooMitraProfile['serviceType'] ?? mitra['subRole'];
    final businessName = alooMitraProfile['businessName'] ?? '';
    final description = alooMitraProfile['description'] ?? '';
    final address = mitra['address'] ?? {};
    final village = address['village'] ?? '';
    final district = address['district'] ?? '';
    final state = address['state'] ?? '';
    final List<dynamic> businessPhotos =
        alooMitraProfile['businessPhotos'] ?? [];

    // Use business name if available, otherwise use firstName lastName
    final displayName = businessName.isNotEmpty
        ? businessName
        : '$firstName $lastName'.trim();

    String locationText = '';
    if (village.isNotEmpty) locationText = village;
    if (district.isNotEmpty) {
      locationText += locationText.isNotEmpty ? ', $district' : district;
    }
    if (state.isNotEmpty) {
      locationText += locationText.isNotEmpty ? ', $state' : state;
    }

    return GestureDetector(
      onTap: () => _showMitraDetails(mitra),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo slider at top (full-width, no padding)
            if (businessPhotos.isNotEmpty)
              _buildPhotoSlider(businessPhotos, height: 160),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar with icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.cardGreen,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryGreen,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _getSubRoleIcon(serviceType),
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name and service type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getSubRoleLabel(serviceType),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Location
                  if (locationText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Description preview if available
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Call & Chat buttons
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Call button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final phone = mitra['phone']?.toString() ?? '';
                            if (phone.isNotEmpty) {
                              launchUrl(Uri.parse('tel:$phone'));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('phone_not_available')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.call,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            tr('call_btn'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Chat button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startChat(mitra),
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            tr('chat'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
