import 'package:aloo_sbji_mandi/core/constants/state_city_data.dart';
import 'package:aloo_sbji_mandi/core/service/mandi_price_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/popular_mandi_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MandiPricesScreen extends StatefulWidget {
  const MandiPricesScreen({super.key});

  @override
  State<MandiPricesScreen> createState() => _MandiPricesScreenState();
}

class _MandiPricesScreenState extends State<MandiPricesScreen> {
  String? selectedState;
  final MandiPriceService _service = MandiPriceService();

  List<Map<String, dynamic>> _mandis = [];
  List<Map<String, dynamic>> _filteredMandis = [];
  Set<String> _favourites = {};
  bool _isLoading = false;
  bool _hasSearched = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favourite_mandis') ?? [];
    if (mounted) {
      setState(() => _favourites = favs.toSet());
    }
  }

  Future<void> _saveFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favourite_mandis', _favourites.toList());
  }

  void _toggleFavourite(String mandiKey) {
    setState(() {
      if (_favourites.contains(mandiKey)) {
        _favourites.remove(mandiKey);
      } else {
        _favourites.add(mandiKey);
      }
    });
    _saveFavourites();
  }

  Future<void> _fetchMandis(String state) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _mandis = [];
      _filteredMandis = [];
    });

    try {
      final mandis = await _service.fetchMandisForState(state: state);
      if (mounted) {
        setState(() {
          _mandis = mandis;
          _applySearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredMandis = List.from(_mandis);
    } else {
      _filteredMandis = _mandis
          .where((m) =>
              (m['market'] as String)
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (m['district'] as String)
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    // Sort: favourites first
    _filteredMandis.sort((a, b) {
      final aFav = _favourites.contains(_mandiKey(a)) ? 0 : 1;
      final bFav = _favourites.contains(_mandiKey(b)) ? 0 : 1;
      if (aFav != bFav) return aFav.compareTo(bFav);
      return (a['market'] as String).compareTo(b['market'] as String);
    });
  }

  String _mandiKey(Map<String, dynamic> mandi) {
    return '${mandi['market']}_${mandi['district']}_${mandi['state']}';
  }

  void _navigateToPriceTrend(Map<String, dynamic> mandi) {
    Navigator.pushNamed(
      context,
      '/mandi_price_trend',
      arguments: {
        'market': mandi['market'],
        'district': mandi['district'],
        'state': mandi['state'] ?? selectedState ?? '',
        'modalPriceQuintal': mandi['modalPriceQuintal'],
        'arrivalDate': mandi['arrivalDate'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          tr('mandi_prices'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // State Dropdown Header
          _buildStateSelector(),

          // Search bar (only when mandis loaded)
          if (_hasSearched && _mandis.isNotEmpty) _buildSearchBar(),

          // Content
          Expanded(
            child: _hasSearched ? _buildMandiList() : _buildInitialView(),
          ),
        ],
      ),
    );
  }

  Widget _buildStateSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedState,
        isExpanded: true,
        dropdownColor: Colors.white,
        hint: Text(
          tr('select_state'),
          style: const TextStyle(color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        style: GoogleFonts.inter(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        items: StateCityData.states
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) {
          setState(() {
            selectedState = v;
            _searchController.clear();
            _searchQuery = '';
          });
          if (v != null) _fetchMandis(v);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.location_on_outlined,
              color: Color(0xFF1B5E20)),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() {
            _searchQuery = v;
            _applySearch();
          });
        },
        decoration: InputDecoration(
          hintText: tr('search_mandi'),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Image.asset(
            'assets/popular_mandi.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            tr('select_state_to_view_mandis'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          popularMandis(
            onMandiTap: (String state, String district) {
              // When a popular mandi is tapped, set state and fetch
              setState(() {
                selectedState = state;
              });
              _fetchMandis(state);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMandiList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1B5E20)),
            const SizedBox(height: 16),
            Text(tr('loading_mandis')),
          ],
        ),
      );
    }

    if (_filteredMandis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? tr('no_matching_mandis')
                  : tr('no_mandis_found'),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredMandis.length,
      itemBuilder: (context, index) {
        final mandi = _filteredMandis[index];
        final key = _mandiKey(mandi);
        final isFav = _favourites.contains(key);
        final modalPrice = mandi['modalPriceQuintal'] as double;
        final arrivalDate = mandi['arrivalDate'] as String;

        return _MandiListTile(
          marketName: mandi['market'] as String,
          district: mandi['district'] as String,
          price: modalPrice,
          arrivalDate: arrivalDate,
          isFavourite: isFav,
          onFavouriteTap: () => _toggleFavourite(key),
          onTap: () => _navigateToPriceTrend(mandi),
        );
      },
    );
  }
}

class _MandiListTile extends StatelessWidget {
  final String marketName;
  final String district;
  final double price;
  final String arrivalDate;
  final bool isFavourite;
  final VoidCallback onFavouriteTap;
  final VoidCallback onTap;

  const _MandiListTile({
    required this.marketName,
    required this.district,
    required this.price,
    required this.arrivalDate,
    required this.isFavourite,
    required this.onFavouriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Market icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.store,
                color: Color(0xFF1B5E20),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Market name & district
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marketName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    district,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  tr('per_quintal'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Favourite button
            GestureDetector(
              onTap: onFavouriteTap,
              child: Icon(
                isFavourite ? Icons.favorite : Icons.favorite_border,
                color: isFavourite ? Colors.red : Colors.grey.shade400,
                size: 24,
              ),
            ),

            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
