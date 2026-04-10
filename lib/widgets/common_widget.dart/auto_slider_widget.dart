import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aloo_sbji_mandi/core/service/advertisement_service.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AutoSliderBanner extends StatefulWidget {
  final List<String>? images; // Local asset images (fallback)
  final double height;
  final Duration autoSlideDuration;
  final Duration animationDuration;
  final bool fetchFromServer; // Whether to fetch banners from server

  const AutoSliderBanner({
    super.key,
    this.images,
    this.height = 180,
    this.autoSlideDuration = const Duration(seconds: 4),
    this.animationDuration = const Duration(milliseconds: 500),
    this.fetchFromServer = true,
  });

  @override
  State<AutoSliderBanner> createState() => _AutoSliderBannerState();
}

class _AutoSliderBannerState extends State<AutoSliderBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  final AdvertisementService _adService = AdvertisementService();
  List<Map<String, dynamic>> _serverBanners = [];
  bool _isLoading = true;

  // Flattened slide data: each entry has 'image', 'link', 'adId'
  List<Map<String, String>> _slideData = [];

  // Default fallback images
  final List<String> _defaultImages = [
    "assets/poster.png",
    "assets/farmaing.png",
    "assets/crop_img.png",
    "assets/popular_mandi.png",
    "assets/weather.png",
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    if (widget.fetchFromServer) {
      try {
        final result = await _adService.getActiveAdvertisements();
        if (result['success'] && mounted) {
          final ads = result['data']['advertisements'] as List?;
          if (ads != null && ads.isNotEmpty) {
            _serverBanners = List<Map<String, dynamic>>.from(ads);
            _buildSlideData();
            if (_slideData.isNotEmpty) {
              setState(() => _isLoading = false);
              _startAutoSlide();
              return;
            }
          }
        }
      } catch (e) {
        print('Error loading banners: $e');
      }
    }

    // Use local images as fallback
    if (mounted) {
      setState(() => _isLoading = false);
      _startAutoSlide();
    }
  }

  void _buildSlideData() {
    _slideData = [];
    for (final banner in _serverBanners) {
      final adId = (banner['_id'] ?? '').toString();
      final images = banner['images'] as List?;
      final redirectUrls = banner['redirectUrls'] as List? ?? [];
      final redirectUrl = (banner['redirectUrl'] ?? '').toString();

      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final img = images[i]?.toString() ?? '';
          if (img.isEmpty) continue;
          // Per-slide link, fallback to ad-level redirectUrl
          final link =
              (i < redirectUrls.length &&
                  redirectUrls[i] != null &&
                  redirectUrls[i].toString().isNotEmpty)
              ? redirectUrls[i].toString()
              : redirectUrl;
          _slideData.add({'image': img, 'link': link, 'adId': adId});
        }
      } else {
        final url = (banner['imageUrl'] ?? '').toString();
        if (url.isNotEmpty) {
          _slideData.add({'image': url, 'link': redirectUrl, 'adId': adId});
        }
      }
    }
  }

  List<String> get _displayImages {
    if (_slideData.isNotEmpty) {
      return _slideData.map((s) => s['image']!).toList();
    }
    return widget.images ?? _defaultImages;
  }

  bool get _isNetworkImages => _slideData.isNotEmpty;

  bool _isBase64Image(String url) {
    return url.startsWith('data:image');
  }

  Widget _buildBase64Image(String base64Str) {
    try {
      String raw = base64Str;
      if (raw.contains(',')) {
        raw = raw.split(',').last;
      }
      final bytes = base64Decode(raw);
      return Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        width: double.infinity,
        height: widget.height,
      );
    } catch (e) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    final imageCount = _displayImages.length;
    if (imageCount <= 1) return;

    _timer = Timer.periodic(widget.autoSlideDuration, (timer) {
      if (_currentPage < imageCount - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: widget.animationDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onSlideTap(String link, String adId) async {
    // Track clicks
    if (adId.isNotEmpty) {
      _adService.trackAdClick(adId);
    }

    if (link.isEmpty) return;

    // Ensure the URL has a scheme
    String url = link;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _displayImages;

    if (_isLoading) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Banner Slider
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageUrl = images[index];

                Widget imageWidget;

                if (!_isNetworkImages) {
                  imageWidget = Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: widget.height,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                } else if (_isBase64Image(imageUrl)) {
                  imageWidget = _buildBase64Image(imageUrl);
                } else {
                  imageWidget = Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: widget.height,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.surfaceVariant(context),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackImage(index);
                    },
                  );
                }

                // Wrap with tap handler for ad links
                final link = (index < _slideData.length)
                    ? (_slideData[index]['link'] ?? '')
                    : '';
                final adId = (index < _slideData.length)
                    ? (_slideData[index]['adId'] ?? '')
                    : '';

                return GestureDetector(
                  onTap: () => _onSlideTap(link, adId),
                  child: imageWidget,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? const Color(0xFF1B4332)
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackImage(int index) {
    final fallbackIndex = index % _defaultImages.length;
    return Image.asset(
      _defaultImages[fallbackIndex],
      fit: BoxFit.contain,
      width: double.infinity,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.image, size: 50, color: Colors.grey),
          ),
        );
      },
    );
  }
}
