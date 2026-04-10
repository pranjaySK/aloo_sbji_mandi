import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/cold_storage_service.dart';
import 'package:aloo_sbji_mandi/core/service/token_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/book_storage_dialog.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/location_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class RentStorageScreen extends StatefulWidget {
  const RentStorageScreen({super.key});

  @override
  State<RentStorageScreen> createState() => _RentStorageScreenState();
}

class _RentStorageScreenState extends State<RentStorageScreen> {
  String? selectedState;
  String? selectedCity;
  List<String> availableCities = [];

  final ColdStorageService _coldStorageService = ColdStorageService();
  final AuthService _authService = AuthService();
  List<dynamic> _coldStorages = [];
  List<dynamic> _nearbyStorages = []; // Storages near user's location
  bool _isLoading = false;
  bool _hasSearched = false;

  // Search bar state
  bool _isSearchBarVisible = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // User's location from profile
  String? _userVillage;
  String? _userDistrict;
  String? _userState;
  String? _userLocationDisplay;

  @override
  void initState() {
    super.initState();
    _loadUserLocationAndStorages();
  }

  /// Load user's location from profile and fetch nearby storages
  Future<void> _loadUserLocationAndStorages() async {
    setState(() => _isLoading = true);

    try {
      // Get user's location from profile
      final user = await _authService.getCurrentUser();
      if (user != null && user['address'] != null) {
        final address = user['address'];
        _userVillage = address['village']?.toString();
        _userDistrict = address['district']?.toString();
        _userState = address['state']?.toString();

        // Build display location
        List<String> locationParts = [];
        if (_userVillage != null && _userVillage!.isNotEmpty) {
          locationParts.add(_userVillage!);
        }
        if (_userDistrict != null && _userDistrict!.isNotEmpty) {
          locationParts.add(_userDistrict!);
        }
        _userLocationDisplay = locationParts.isNotEmpty
            ? locationParts.join(', ')
            : null;
      }

      // Load nearby storages based on user's location
      await _loadNearbyStorages();
    } catch (e) {
      print('Error loading user location: $e');
      // Still try to load all storages if user location fails
      await _loadNearbyStorages();
    }
  }

  Future<void> _loadNearbyStorages() async {
    // If user has location, search nearby first
    if (_userDistrict != null && _userDistrict!.isNotEmpty) {
      // First try to find storages in user's district/village
      final nearbyResult = await _coldStorageService.getAllColdStorages(
        nearbySearch: _userVillage ?? _userDistrict,
        state: _userState,
      );

      if (nearbyResult['success']) {
        _nearbyStorages = nearbyResult['data']['coldStorages'] ?? [];
      }

      // If no nearby storages found, try searching by district only
      if (_nearbyStorages.isEmpty && _userDistrict != null) {
        final districtResult = await _coldStorageService.getAllColdStorages(
          district: _userDistrict,
          state: _userState,
        );

        if (districtResult['success']) {
          _nearbyStorages = districtResult['data']['coldStorages'] ?? [];
        }
      }
    }

    // Load all storages (including unavailable ones)
    final allResult = await _coldStorageService.getAllColdStorages();

    setState(() {
      _isLoading = false;
      if (allResult['success']) {
        _coldStorages = allResult['data']['coldStorages'] ?? [];
      }
    });
  }

  Future<void> _searchStorages() async {
    if (selectedState == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_select_state'))));
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final result = await _coldStorageService.getAllColdStorages(
      state: selectedState,
      city: selectedCity,
    );

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _coldStorages = result['data']['coldStorages'] ?? [];
      }
    });
  }

  void _onStateChanged(String? state) {
    setState(() {
      selectedState = state;
      selectedCity = null;
      availableCities = state != null
          ? StateCityData.getCitiesForState(state)
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearchBarVisible) {
              setState(() {
                _isSearchBarVisible = false;
                _searchQuery = '';
                _searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSearchBarVisible
            ? Material(
                color: Colors.transparent,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  enableInteractiveSelection: true,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: tr('search_cold_storage_hint'),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              )
            : Text(
                tr('rent_storage'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearchBarVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearchBarVisible) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearchBarVisible = !_isSearchBarVisible;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _headerSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _hasSearched
                              ? (AppLocalizations.isHindi
                                    ? "${tr('search_results_label')} (${_coldStorages.length})"
                                    : "Search Results (${_coldStorages.length})")
                              : (AppLocalizations.isHindi
                                    ? "${tr('nearby_cold_storage')}${_nearbyStorages.isNotEmpty ? ' (${_nearbyStorages.length})' : ''}"
                                    : "Cold storage near you${_nearbyStorages.isNotEmpty ? ' (${_nearbyStorages.length})' : ''}"),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Show "View All" - same nearby storages, just a link for navigation/emphasis
                      if (!_hasSearched && _nearbyStorages.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            // Just scroll or highlight - we're already showing all nearby
                            // This is for UX consistency, doesn't change the list
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            '${tr('view_all')} (${_nearbyStorages.length})',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildStorageList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // State and City in a Row for compact layout
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  hint: "Select State",
                  value: selectedState,
                  items: StateCityData.states,
                  onChanged: _onStateChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  hint: "Select City",
                  value: selectedCity,
                  items: availableCities,
                  onChanged: (v) => setState(() => selectedCity = v),
                  enabled: selectedState != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _searchStorages,
              child: Text(
                "Search",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    // Use nearby storages if available and not searched, otherwise use all storages
    var displayStorages = !_hasSearched && _nearbyStorages.isNotEmpty
        ? _nearbyStorages
        : _coldStorages;

    // Apply search filter if query is not empty
    if (_searchQuery.isNotEmpty) {
      displayStorages = displayStorages.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final city = (s['city'] ?? '').toString().toLowerCase();
        final village = (s['village'] ?? '').toString().toLowerCase();
        final state = (s['state'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) ||
            city.contains(_searchQuery) ||
            village.contains(_searchQuery) ||
            state.contains(_searchQuery);
      }).toList();
    }

    if (displayStorages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ac_unit, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _hasSearched
                  ? tr('no_cold_storages_in_area')
                  : tr('no_cold_storages_available'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (!_hasSearched && _userLocationDisplay == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  tr('update_location_profile'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      itemCount: displayStorages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final storage = displayStorages[index];
        return _StorageCard(
          storage: storage,
          onTap: () => _navigateToDetail(storage),
        );
      },
    );
  }

  void _navigateToDetail(Map<String, dynamic> storage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColdStorageDetailScreen(storage: storage),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: GoogleFonts.inter(color: AppColors.border),
        overflow: TextOverflow.ellipsis,
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Storage Card Widget
class _StorageCard extends StatelessWidget {
  final Map<String, dynamic> storage;
  final VoidCallback onTap;

  const _StorageCard({required this.storage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = storage['name'] ?? 'Cold Storage';
    final averageRating = (storage['averageRating'] ?? 0).toDouble();
    final images = storage['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final city = storage['city'] ?? '';
    final village = storage['village'] ?? '';
    final locationText = village.isNotEmpty ? '$village, $city' : city;
    final isAvailable = storage['isAvailable'] ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.7,
        child: Container(
          decoration: BoxDecoration(
            color: isAvailable ? const Color(0xFF0B5D1E) : Colors.grey[700],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Main Image
                    Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderImage(),
                              )
                            : _buildPlaceholderImage(),
                      ),
                    ),
                    // Unavailable badge overlay
                    if (!isAvailable)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.block,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Space Unavailable',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Location badge in top right
                    if (locationText.isNotEmpty)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                locationText.length > 15
                                    ? '${locationText.substring(0, 12)}...'
                                    : locationText,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Name and Rating Section
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Storage Name
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rating
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            averageRating > 0
                                ? averageRating.toStringAsFixed(1)
                                : '0.0',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: Image.asset(
        "assets/cloud_storage.png",
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.ac_unit, size: 50, color: Colors.grey[400]),
      ),
    );
  }
}

// Cold Storage Detail Screen
class ColdStorageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> storage;

  const ColdStorageDetailScreen({super.key, required this.storage});

  @override
  State<ColdStorageDetailScreen> createState() =>
      _ColdStorageDetailScreenState();
}

class _ColdStorageDetailScreenState extends State<ColdStorageDetailScreen> {
  final ChatService _chatService = ChatService();
  final ColdStorageService _coldStorageService = ColdStorageService();
  final TokenService _tokenService = TokenService();
  bool _isLoadingChat = false;
  bool _isLoadingData = true;
  bool _isRequestingToken = false;
  bool _isSubmittingRating = false;
  late Map<String, dynamic> storage;
  int _userRating = 0;

  @override
  void initState() {
    super.initState();
    storage = widget.storage;
    _fetchLatestData();
  }

  Future<void> _fetchLatestData() async {
    setState(() => _isLoadingData = true);

    final storageId = widget.storage['_id'];
    if (storageId != null) {
      final result = await _coldStorageService.getColdStorageById(storageId);
      if (result['success'] && mounted) {
        setState(() {
          storage = result['data']['coldStorage'] ?? widget.storage;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _openBookingDialog() async {
    await showDialog(
      context: context,
      builder: (context) => BookStorageDialog(
        storage: storage,
        onBooked: (success) {
          if (success) {
            // Optionally refresh storage data
          }
        },
      ),
    );
  }

  Future<void> _startChatWithOwner() async {
    // Get owner ID with better null safety
    String? ownerId;
    String ownerName = 'Cold Storage Owner';

    final owner = storage['owner'];
    if (owner != null && owner is Map && owner['_id'] != null) {
      ownerId = owner['_id'].toString();
      ownerName = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
          .trim();
      if (ownerName.isEmpty) ownerName = 'Cold Storage Owner';
    } else if (storage['owner'] != null && storage['owner'] is String) {
      // Owner might be stored as just an ID string
      ownerId = storage['owner'];
    }

    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('owner_info_not_available')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingChat = true);

    final result = await _chatService.startOrGetConversation(ownerId);

    setState(() => _isLoadingChat = false);

    if (result['success']) {
      // Backend returns conversation directly in data, or nested under 'conversation'
      final data = result['data'];
      final conversation = data is Map ? (data['conversation'] ?? data) : null;
      if (conversation != null && conversation['_id'] != null && mounted) {
        // Get owner data for ChatUser
        final ownerData = storage['owner'];

        final chatUser = ChatUser(
          id: ownerId,
          firstName: ownerData is Map
              ? (ownerData['firstName']?.toString() ?? ownerName)
              : ownerName,
          lastName: ownerData is Map
              ? (ownerData['lastName']?.toString() ?? '')
              : '',
          role: 'coldStorage',
          isOnline: ownerData is Map ? (ownerData['isOnline'] ?? false) : false,
          phone: ownerData is Map ? ownerData['phone']?.toString() : null,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversation['_id']?.toString() ?? '',
              otherUser: chatUser,
              contextType: 'storage',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('could_not_start_conversation')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('could_not_start_chat')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callOwner() async {
    // Try storage['phone'] first, then owner's phone
    final phone =
        storage['phone'] ??
        (storage['owner'] is Map ? storage['owner']['phone'] : null);
    if (phone != null && phone.toString().isNotEmpty) {
      final uri = Uri.parse('tel:${phone.toString()}');
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('phone_not_available'))));
      }
    }
  }

  Future<void> _requestToken() async {
    final storageId = storage['_id'];
    if (storageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('storage_id_not_found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show token request dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _TokenRequestDialog(storageName: storage['name'] ?? 'Cold Storage'),
    );

    if (result == null) return;

    setState(() => _isRequestingToken = true);

    final response = await _tokenService.requestToken(
      coldStorageId: storageId,
      purpose: result['purpose'],
      expectedQuantity: result['quantity'],
    );

    setState(() => _isRequestingToken = false);

    if (response['success'] == true) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.blue,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.isHindi
                      ? tr('request_sent_title')
                      : 'Request Sent!',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.isHindi
                        ? tr('token_request_sent_msg')
                        : 'Your token request has been sent to the cold storage owner.\n\nYou will receive your token number when they approve it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/my_token');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('track_token'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? tr('failed_to_get_token')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRating(int rating) async {
    final storageId = storage['_id'];
    if (storageId == null) return;

    setState(() => _isSubmittingRating = true);

    final result = await _coldStorageService.addRating(
      coldStorageId: storageId,
      rating: rating,
    );

    setState(() => _isSubmittingRating = false);

    if (result['success']) {
      setState(() {
        _userRating = rating;
        storage['averageRating'] = result['data']['averageRating'];
        storage['totalRatings'] = result['data']['totalRatings'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('rating_submitted')),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('failed_to_submit_rating')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog() {
    int tempRating = _userRating;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tr('rate_storage'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                storage['name'] ?? 'Cold Storage',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => tempRating = index + 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < tempRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                tempRating > 0 ? '$tempRating / 5' : tr('tap_to_rate'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: tempRating > 0
                  ? () {
                      Navigator.pop(context);
                      _submitRating(tempRating);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      tr('submit'),
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = storage['owner'] ?? {};
    final availableCapacity = storage['availableCapacity'] ?? 0;
    final totalCapacity = storage['capacity'] ?? 0;
    final pricePerTon = storage['pricePerTon'] ?? 0;
    final isAvailable = storage['isAvailable'] ?? false;
    final percentUsed = totalCapacity > 0
        ? ((totalCapacity - availableCapacity) / totalCapacity * 100).toInt()
        : 0;
    final images = storage['images'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          storage['name'] ?? 'Cold Storage',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLatestData,
            tooltip: tr('refresh'),
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : RefreshIndicator(
              onRefresh: _fetchLatestData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Header — carousel if multiple images
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image(s)
                          if (images.isNotEmpty)
                            PageView.builder(
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  images[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                        "assets/cloud_storage.png",
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) =>
                                            Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.ac_unit,
                                                size: 80,
                                                color: Colors.grey,
                                              ),
                                            ),
                                      ),
                                );
                              },
                            )
                          else
                            Image.asset(
                              "assets/cloud_storage.png",
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.ac_unit,
                                      size: 80,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          // Photo count indicator (top right)
                          if (images.length > 1)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${images.length} Photos — Swipe',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Availability badge and rating
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isAvailable
                                        ? '✓ Space Available'
                                        : '✗ Space Unavailable',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(storage['averageRating'] ?? 0).toStringAsFixed(1)}',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name & Location
                          Text(
                            storage['name'] ?? 'Cold Storage',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.primaryGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${storage['address']}, ${storage['city']}, ${storage['state']} - ${storage['pincode']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // GPS Location Map (if available)
                          if (storage['captureLocation'] != null &&
                              storage['captureLocation']['latitude'] != null &&
                              storage['captureLocation']['longitude'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: LocationMapWidget(
                                latitude: (storage['captureLocation']['latitude'] as num).toDouble(),
                                longitude: (storage['captureLocation']['longitude'] as num).toDouble(),
                                address: storage['captureLocation']['address'] as String?,
                                height: 180,
                                compact: false,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Price Card (removed capacity section for farmers)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryGreen),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price per Packet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '₹$pricePerTon',
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.currency_rupee,
                                  size: 40,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Owner Info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Owner',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.blue.withOpacity(
                                        0.2,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            storage['phone'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone,
                                        color: AppColors.primaryGreen,
                                      ),
                                      onPressed: _callOwner,
                                    ),
                                    _isLoadingChat
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.chat,
                                              color: AppColors.primaryGreen,
                                            ),
                                            onPressed: _startChatWithOwner,
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Book Now Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (isAvailable && availableCapacity > 0)
                                  ? _openBookingDialog
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (isAvailable && availableCapacity > 0)
                                    ? AppColors.primaryGreen
                                    : Colors.grey[400],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey[400],
                              ),
                              child: Text(
                                (isAvailable && availableCapacity > 0)
                                    ? 'Book Storage Space'
                                    : 'Space Unavailable',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // const SizedBox(height: 12),

                          // // Request Token Button — COMMENTED OUT (moved to My Token screen)
                          // SizedBox(
                          //   width: double.infinity,
                          //   height: 50,
                          //   child: ElevatedButton.icon(
                          //     onPressed: _isRequestingToken
                          //         ? null
                          //         : _requestToken,
                          //     icon: _isRequestingToken
                          //         ? const SizedBox(
                          //             width: 20,
                          //             height: 20,
                          //             child: CircularProgressIndicator(
                          //               strokeWidth: 2,
                          //               color: Colors.white,
                          //             ),
                          //           )
                          //         : const Icon(
                          //             Icons.send_rounded,
                          //             color: Colors.white,
                          //           ),
                          //     label: Text(
                          //       _isRequestingToken
                          //           ? 'Sending...'
                          //           : 'Request Token (टोकन अनुरोध)',
                          //       style: GoogleFonts.inter(
                          //         fontSize: 16,
                          //         fontWeight: FontWeight.w600,
                          //         color: Colors.white,
                          //       ),
                          //     ),
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: Colors.blue.shade700,
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(12),
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 24),

                          // Rating Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tr('rating_reviews'),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(storage['averageRating'] ?? 0).toStringAsFixed(1)} (${storage['totalRatings'] ?? 0})',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // User can rate
                                Row(
                                  children: [
                                    Text(
                                      tr('rate_this_storage'),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 12),
                                    ...List.generate(5, (index) {
                                      return GestureDetector(
                                        onTap: () => _showRatingDialog(),
                                        child: Icon(
                                          index < _userRating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 28,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _showRatingDialog,
                                    icon: const Icon(Icons.rate_review),
                                    label: Text(
                                      _userRating > 0
                                          ? tr('change_rating')
                                          : tr('give_rating'),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryGreen,
                                      side: const BorderSide(
                                        color: AppColors.primaryGreen,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _capacityItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.inventory_2, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

// Token Request Dialog for farmers
class _TokenRequestDialog extends StatefulWidget {
  final String storageName;

  const _TokenRequestDialog({required this.storageName});

  @override
  State<_TokenRequestDialog> createState() => _TokenRequestDialogState();
}

class _TokenRequestDialogState extends State<_TokenRequestDialog> {
  String _purpose = 'storage';
  final _quantityController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.send_rounded, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.isHindi
                  ? tr('token_request_dialog_title')
                  : 'Request Token',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storageName,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Purpose selection
            Text(
              tr('select_purpose'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPurposeChip('storage', tr('store_potatoes_option')),
            const SizedBox(height: 8),
            _buildPurposeChip('withdrawal', tr('withdraw_potatoes_option')),
            const SizedBox(height: 8),
            _buildPurposeChip('inspection', tr('inspection_option')),

            const SizedBox(height: 20),

            // Quantity (optional)
            Text(
              tr('expected_quantity'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: tr('quantity_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Note / Remark (Optional)
            Text(
              tr('remark_optional'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remarkController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: tr('remark_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            final quantity = int.tryParse(_quantityController.text);
            Navigator.pop(context, {
              'purpose': _purpose,
              'quantity': quantity,
              'remark': _remarkController.text.trim().isNotEmpty
                  ? _remarkController.text.trim()
                  : null,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            AppLocalizations.isHindi ? tr('send_request_btn') : 'Send Request',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildPurposeChip(String value, String label) {
    final isSelected = _purpose == value;
    return GestureDetector(
      onTap: () => setState(() => _purpose = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue[800] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
