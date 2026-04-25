import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Map<String, String> _emptyLocation() => {
        'village': '',
        'district': '',
        'state': '',
        'pincode': '',
      };

  bool _hasUsefulData(Map<String, String> m) {
    final pin = (m['pincode'] ?? '').trim();
    final st = (m['state'] ?? '').trim();
    return pin.length == 6 || st.isNotEmpty;
  }

  /// Device GPS + reverse geocoding first; falls back to IP lookup.
  Future<Map<String, String>> getLocationData({BuildContext? context}) async {
    // ── Previous behavior (IP only, no GPS) — kept for reference, not used as primary path
    // Map<String, String> locationData = {
    //   'village': '',
    //   'district': '',
    //   'state': '',
    //   'pincode': '',
    // };
    // try {
    //   final ipLocation = await _getLocationFromIP();
    //   if (ipLocation != null) {
    //     locationData = ipLocation;
    //   }
    // } catch (e) {
    //   print('Location service error: $e');
    // }
    // return locationData;

    try {
      final gps = await _getLocationFromGps(context: context);
      if (_hasUsefulData(gps)) return gps;
    } catch (e) {
      // ignore — try IP
    }

    try {
      final ipLocation = await _getLocationFromIP();
      if (ipLocation != null) return ipLocation;
    } catch (e) {
      // ignore
    }

    return _emptyLocation();
  }

  /// Reverse geocode current position (when permission granted).
  Future<Map<String, String>> _getLocationFromGps({BuildContext? context}) async {
    final hasPermission = await handleLocationPermission(context);
    if (!hasPermission) {
      return _emptyLocation();
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return _emptyLocation();
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );

    if (placemarks.isEmpty) return _emptyLocation();

    final p = placemarks.first;
    var village = '';
    for (final s in [p.locality, p.subLocality, p.name]) {
      if (s != null && s.trim().isNotEmpty) {
        village = s.trim();
        break;
      }
    }

    final district = (p.subAdministrativeArea ?? p.locality ?? '').trim();
    final state = (p.administrativeArea ?? '').trim();
    final pincode = (p.postalCode ?? '').trim();

    return {
      'village': village,
      'district': district,
      'state': state,
      'pincode': pincode,
    };
  }

  /// Get location from IP address (works on web, no permissions needed)
  Future<Map<String, String>?> _getLocationFromIP() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=city,regionName,country,zip',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'village': data['city'] ?? '',
          'district': data['city'] ?? '',
          'state': data['regionName'] ?? '',
          'pincode': data['zip'] ?? '',
        };
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ── OLD stubs (always false) — replaced with real checks
  // Future<bool> hasLocationPermission() async {
  //   return false;
  // }
  // Future<bool> requestLocationPermission() async {
  //   return false;
  // }

  Future<bool> hasLocationPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  Future<bool> requestLocationPermission({BuildContext? context}) async {
    return handleLocationPermission(context);
  }

  Future<bool> handleLocationPermission(BuildContext? context) async {
    return handlePermissions(context, location: true);
  }

  Future<bool> handleCameraPermission(BuildContext? context) async {
    return handlePermissions(context, camera: true);
  }

  Future<bool> handlePermissions(
    BuildContext? context, {
    bool location = false,
    bool camera = false,
  }) async {
    bool locationGranted = true;
    bool cameraGranted = true;
    bool locationPermanentlyDenied = false;
    bool cameraPermanentlyDenied = false;

    if (location) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        locationPermanentlyDenied = true;
        locationGranted = false;
      } else if (permission == LocationPermission.denied) {
        locationGranted = false;
      }
    }

    if (camera) {
      ph.PermissionStatus status = await ph.Permission.camera.status;
      if (status.isDenied) {
        status = await ph.Permission.camera.request();
      }
      if (status.isPermanentlyDenied) {
        cameraPermanentlyDenied = true;
        cameraGranted = false;
      } else if (status.isDenied) {
        cameraGranted = false;
      }
    }

    if (locationPermanentlyDenied || cameraPermanentlyDenied) {
      if (context != null && context.mounted) {
        _showPermissionDeniedDialog(
          context: context,
          locationDenied: locationPermanentlyDenied,
          cameraDenied: cameraPermanentlyDenied,
        );
      }
      return false;
    }

    return locationGranted && cameraGranted;
  }

  void _showPermissionDeniedDialog({
    required BuildContext context,
    required bool locationDenied,
    required bool cameraDenied,
  }) {
    final bool bothDenied = locationDenied && cameraDenied;

    final IconData icon = bothDenied
        ? Icons.app_settings_alt_rounded
        : locationDenied
            ? Icons.location_disabled_rounded
            : Icons.camera_alt_outlined;

    final String title = bothDenied
        ? tr('permissions_required')
        : locationDenied
            ? tr('location_permission_required')
            : tr('camera_permission_required');

    final String message = bothDenied
        ? tr('location_camera_denied_msg')
        : locationDenied
            ? tr('location_denied_msg')
            : tr('camera_denied_msg');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardBg(ctx),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bothDenied)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_disabled_rounded,
                        size: 28,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.no_photography_outlined,
                        size: 28,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(ctx),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary(ctx),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (bothDenied) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _permissionRow(
                        Icons.location_on_rounded,
                        tr('perm_location'),
                      ),
                      const SizedBox(height: 6),
                      _permissionRow(
                        Icons.camera_alt_rounded,
                        tr('perm_camera'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        tr('cancel'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ph.openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        tr('open_settings'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
    );
  }

  Widget _permissionRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.red.shade400),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tr('perm_denied'),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
