import 'package:aloo_sbji_mandi/core/service/google_geocoding_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// A reusable widget that displays a Google Static Map image with a pin marker.
/// Tapping the map opens Google Maps at the exact location.
///
/// Usage:
/// ```dart
/// LocationMapWidget(
///   latitude: 26.8467,
///   longitude: 80.9462,
///   address: "Lucknow, Uttar Pradesh",
///   height: 180,
/// )
/// ```
class LocationMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final double height;
  final int zoom;
  final bool showAddress;
  final bool showCoordinates;
  final bool compact; // Compact mode for listing cards
  final BorderRadius? borderRadius;

  const LocationMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.height = 180,
    this.zoom = 15,
    this.showAddress = true,
    this.showCoordinates = true,
    this.compact = false,
    this.borderRadius,
  });

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  final GoogleGeocodingService _geocodingService = GoogleGeocodingService();
  String? _mapUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMapUrl();
  }

  @override
  void didUpdateWidget(LocationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _loadMapUrl();
    }
  }

  Future<void> _loadMapUrl() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final apiKey = await _geocodingService.getApiKey();
      if (apiKey != null) {
        final url = _geocodingService.buildStaticMapUrl(
          latitude: widget.latitude,
          longitude: widget.longitude,
          zoom: widget.zoom,
          width: 600,
          height: widget.compact ? 200 : 300,
          apiKey: apiKey,
        );
        if (mounted) {
          setState(() {
            _mapUrl = url;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _openInGoogleMaps() async {
    final url = GoogleGeocodingService.buildGoogleMapsUrl(
      latitude: widget.latitude,
      longitude: widget.longitude,
      label: widget.address,
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactMap();
    }
    return _buildFullMap();
  }

  /// Full map widget with address text (for detail screens)
  Widget _buildFullMap() {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.green.shade200),
        color: Colors.green.shade50,
      ),
      child: Row(
        children: [
          // Location icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on,
              color: Colors.green.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Address text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo Capture Location',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                if (widget.address != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.address!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Navigate button
          GestureDetector(
            onTap: _openInGoogleMaps,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Navigate',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact map widget (for create screen — shows map below captured photo)
  Widget _buildCompactMap() {
    return GestureDetector(
      onTap: _openInGoogleMaps,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.3),
          ),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          child: Stack(
            children: [
              _buildMapContent(),
              // "Tap to view on map" overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view on Google Maps',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (widget.address != null)
                        Flexible(
                          child: Text(
                            widget.address!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

  /// Build the map image content (loading / error / image)
  Widget _buildMapContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading map...',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError || _mapUrl == null) {
      return _buildFallbackMap();
    }

    return Image.network(
      _mapUrl!,
      width: double.infinity,
      height: widget.height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildFallbackMap(),
    );
  }

  /// Fallback: clean address-based placeholder when static map can't load
  Widget _buildFallbackMap() {
    return GestureDetector(
      onTap: _openInGoogleMaps,
      child: Container(
        width: double.infinity,
        height: widget.height,
        color: Colors.green.shade50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 40,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 8),
            if (widget.address != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.address!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation_rounded, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  'Tap to navigate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
