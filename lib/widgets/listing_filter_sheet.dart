import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Filter data model used by listing screens
class ListingFilters {
  String? variety;
  String? size; // Small, Medium, Large
  String? quality; // Low, Average, Good
  String? sourceType; // field, cold_storage
  int? minPrice;
  int? maxPrice;
  String? sortBy; // price_low, price_high, newest, oldest

  ListingFilters({
    this.variety,
    this.size,
    this.quality,
    this.sourceType,
    this.minPrice,
    this.maxPrice,
    this.sortBy,
  });

  ListingFilters copyWith({
    String? variety,
    String? size,
    String? quality,
    String? sourceType,
    int? minPrice,
    int? maxPrice,
    String? sortBy,
    bool clearVariety = false,
    bool clearSize = false,
    bool clearQuality = false,
    bool clearSourceType = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearSortBy = false,
  }) {
    return ListingFilters(
      variety: clearVariety ? null : (variety ?? this.variety),
      size: clearSize ? null : (size ?? this.size),
      quality: clearQuality ? null : (quality ?? this.quality),
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
    );
  }

  bool get hasActiveFilters =>
      variety != null ||
      size != null ||
      quality != null ||
      sourceType != null ||
      minPrice != null ||
      maxPrice != null;

  int get activeFilterCount {
    int count = 0;
    if (variety != null) count++;
    if (size != null) count++;
    if (quality != null) count++;
    if (sourceType != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }

  void clear() {
    variety = null;
    size = null;
    quality = null;
    sourceType = null;
    minPrice = null;
    maxPrice = null;
    sortBy = null;
  }
}

/// Reusable filter bottom sheet for listing screens
class ListingFilterSheet extends StatefulWidget {
  final ListingFilters currentFilters;
  final bool showSourceType;

  const ListingFilterSheet({
    super.key,
    required this.currentFilters,
    this.showSourceType = true,
  });

  @override
  State<ListingFilterSheet> createState() => _ListingFilterSheetState();

  /// Shows the filter sheet and returns updated filters (or null if dismissed)
  static Future<ListingFilters?> show(
    BuildContext context, {
    required ListingFilters currentFilters,
    bool showSourceType = true,
  }) {
    return showModalBottomSheet<ListingFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingFilterSheet(
        currentFilters: currentFilters,
        showSourceType: showSourceType,
      ),
    );
  }
}

class _ListingFilterSheetState extends State<ListingFilterSheet> {
  late TextEditingController _varietyController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  String? _selectedSize;
  String? _selectedQuality;
  String? _selectedSourceType;
  String? _selectedSortBy;

  final _sizes = ['Small', 'Medium', 'Large'];
  final _qualities = ['Low', 'Average', 'Good'];
  final _sourceTypes = ['field', 'cold_storage'];
  final _sortOptions = ['price_low', 'price_high', 'newest', 'oldest'];

  @override
  void initState() {
    super.initState();
    final f = widget.currentFilters;
    _varietyController = TextEditingController(text: f.variety ?? '');
    _minPriceController = TextEditingController(
      text: f.minPrice?.toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: f.maxPrice?.toString() ?? '',
    );
    _selectedSize = f.size;
    _selectedQuality = f.quality;
    _selectedSourceType = f.sourceType;
    _selectedSortBy = f.sortBy;
  }

  @override
  void dispose() {
    _varietyController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String _sizeLabel(String s) {
    switch (s) {
      case 'Small':
        return tr('small');
      case 'Medium':
        return tr('medium');
      case 'Large':
        return tr('large');
      default:
        return s;
    }
  }

  String _qualityLabel(String q) {
    switch (q) {
      case 'Low':
        return tr('quality_low');
      case 'Average':
        return tr('quality_avg');
      case 'Good':
        return tr('quality_good');
      default:
        return q;
    }
  }

  String _sourceLabel(String s) {
    switch (s) {
      case 'field':
        return tr('field');
      case 'cold_storage':
        return tr('cold_storage');
      default:
        return s;
    }
  }

  String _sortLabel(String s) {
    switch (s) {
      case 'price_low':
        return 'Price: Low → High';
      case 'price_high':
        return 'Price: High → Low';
      case 'newest':
        return tr('newest_first');
      case 'oldest':
        return tr('oldest_first');
      default:
        return s;
    }
  }

  void _applyFilters() {
    final filters = ListingFilters(
      variety: _varietyController.text.trim().isEmpty
          ? null
          : _varietyController.text.trim(),
      size: _selectedSize,
      quality: _selectedQuality,
      sourceType: _selectedSourceType,
      minPrice: int.tryParse(_minPriceController.text.trim()),
      maxPrice: int.tryParse(_maxPriceController.text.trim()),
      sortBy: _selectedSortBy,
    );
    Navigator.pop(context, filters);
  }

  void _clearAll() {
    setState(() {
      _varietyController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedSize = null;
      _selectedQuality = null;
      _selectedSourceType = null;
      _selectedSortBy = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  tr('filters'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: Text(
                    tr('clear_all'),
                    style: TextStyle(color: Colors.red[400], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable filter content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Search by Variety ---
                  _sectionTitle(tr('variety')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _varietyController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Pukhraj, Jyoti, Chipsona...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Size ---
                  _sectionTitle(tr('size')),
                  const SizedBox(height: 8),
                  _buildChipRow(
                    items: _sizes,
                    selected: _selectedSize,
                    labelBuilder: _sizeLabel,
                    onSelected: (val) => setState(
                      () => _selectedSize = val == _selectedSize ? null : val,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Quality ---
                  _sectionTitle(tr('quality')),
                  const SizedBox(height: 8),
                  _buildChipRow(
                    items: _qualities,
                    selected: _selectedQuality,
                    labelBuilder: _qualityLabel,
                    onSelected: (val) => setState(
                      () => _selectedQuality = val == _selectedQuality
                          ? null
                          : val,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Source Type ---
                  if (widget.showSourceType) ...[
                    _sectionTitle(tr('source')),
                    const SizedBox(height: 8),
                    _buildChipRow(
                      items: _sourceTypes,
                      selected: _selectedSourceType,
                      labelBuilder: _sourceLabel,
                      onSelected: (val) => setState(
                        () => _selectedSourceType = val == _selectedSourceType
                            ? null
                            : val,
                      ),
                      icons: [Icons.grass, Icons.ac_unit],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- Price Range ---
                  _sectionTitle(tr('price_range')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Min ₹',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            prefixText: '₹ ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '–',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max ₹',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            prefixText: '₹ ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- Sort By ---
                  _sectionTitle(tr('sort_by')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions.map((opt) {
                      final isSelected = _selectedSortBy == opt;
                      return ChoiceChip(
                        label: Text(
                          _sortLabel(opt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => setState(
                          () => _selectedSortBy = opt == _selectedSortBy
                              ? null
                              : opt,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom apply button
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  tr('apply_filters'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildChipRow({
    required List<String> items,
    required String? selected,
    required String Function(String) labelBuilder,
    required void Function(String) onSelected,
    List<IconData>? icons,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(items.length, (i) {
        final isSelected = selected == items[i];
        return ChoiceChip(
          avatar: icons != null
              ? Icon(
                  icons[i],
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                )
              : null,
          label: Text(
            labelBuilder(items[i]),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : null,
            ),
          ),
          selected: isSelected,
          selectedColor: AppColors.primaryGreen,
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (_) => onSelected(items[i]),
        );
      }),
    );
  }
}

/// A small filter bar with active filter chips + filter button.
/// Place this above listing grids for easy access.
class ListingFilterBar extends StatelessWidget {
  final ListingFilters filters;
  final VoidCallback onFilterTap;
  final VoidCallback onClearAll;

  const ListingFilterBar({
    super.key,
    required this.filters,
    required this.onFilterTap,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filters.variety != null) {
      chips.add(_chip(filters.variety!, Icons.local_florist));
    }
    if (filters.size != null) {
      chips.add(_chip(filters.size!, Icons.straighten));
    }
    if (filters.quality != null) {
      chips.add(_chip(filters.quality!, Icons.grade));
    }
    if (filters.sourceType != null) {
      chips.add(
        _chip(
          filters.sourceType == 'field' ? tr('field') : tr('cold_storage'),
          filters.sourceType == 'field' ? Icons.grass : Icons.ac_unit,
        ),
      );
    }
    if (filters.minPrice != null || filters.maxPrice != null) {
      final priceText = filters.minPrice != null && filters.maxPrice != null
          ? '₹${filters.minPrice}-${filters.maxPrice}'
          : filters.minPrice != null
          ? '₹${filters.minPrice}+'
          : '≤ ₹${filters.maxPrice}';
      chips.add(_chip(priceText, Icons.currency_rupee));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Filter button
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: filters.hasActiveFilters
                    ? AppColors.primaryGreen
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: filters.hasActiveFilters
                        ? Colors.white
                        : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filters.hasActiveFilters
                        ? '${tr('filters')} (${filters.activeFilterCount})'
                        : tr('filters'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: filters.hasActiveFilters
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active filter chips
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: chips),
              ),
            ),
            // Clear all button
            GestureDetector(
              onTap: onClearAll,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 18, color: Colors.red[400]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
