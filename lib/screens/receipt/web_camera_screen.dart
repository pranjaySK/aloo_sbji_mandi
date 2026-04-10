import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebCameraScreen extends StatefulWidget {
  const WebCameraScreen({super.key});

  @override
  State<WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<WebCameraScreen> {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _isCameraReady = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _capturedImageBase64;
  final String _viewType =
      'camera-view-${DateTime.now().millisecondsSinceEpoch}';
  bool _isFrontCamera = false; // Track current camera mode

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Stop existing stream if any
      _stopCamera();

      setState(() {
        _isCameraReady = false;
        _hasError = false;
      });

      // Create video element
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = _isFrontCamera
            ? 'scaleX(-1)'
            : 'scaleX(1)'; // Mirror only front camera

      // Register the view
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _videoElement!,
      );

      // Request camera access
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': _isFrontCamera
              ? 'user'
              : 'environment', // user = front, environment = rear
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
        'audio': false,
      });

      if (_mediaStream != null) {
        _videoElement!.srcObject = _mediaStream;
        await _videoElement!.play();

        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _initializeCamera();
  }

  Future<void> _capturePhoto() async {
    if (_videoElement == null || !_isCameraReady) return;

    try {
      // Create canvas to capture frame
      final canvas = html.CanvasElement(
        width: _videoElement!.videoWidth,
        height: _videoElement!.videoHeight,
      );

      final ctx = canvas.context2D;

      // Draw the video frame (flipped back to normal)
      ctx.translate(canvas.width!, 0);
      ctx.scale(-1, 1);
      ctx.drawImage(_videoElement!, 0, 0);

      // Convert to base64
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);

      setState(() {
        _capturedImageBase64 = dataUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImageBase64 = null;
    });
  }

  void _confirmPhoto() {
    if (_capturedImageBase64 != null) {
      _stopCamera();
      Navigator.pop(context, _capturedImageBase64);
    }
  }

  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _videoElement?.pause();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            _stopCamera();
            Navigator.pop(context);
          },
        ),
        title: Text(
          '📸 Capture Receipt',
          style: GoogleFonts.inter(color: Colors.white),
        ),
      ),
      body: _hasError
          ? _buildErrorWidget()
          : _capturedImageBase64 != null
          ? _buildPreviewWidget()
          : _buildCameraWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Access Required',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please allow camera access in your browser to capture receipt photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
                _initializeCamera();
              },
              icon: const Icon(Icons.refresh),
              label: Text(tr('try_again')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraWidget() {
    return Stack(
      children: [
        // Camera View
        if (_isCameraReady)
          Positioned.fill(child: HtmlElementView(viewType: _viewType))
        else
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Starting camera...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

        // Camera overlay
        if (_isCameraReady) ...[
          // Frame guide
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Hint text
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Text(
              'Align receipt within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Switch camera button
                GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // Capture button
                GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 36,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),

                // Placeholder for symmetry
                const SizedBox(width: 56, height: 56),
              ],
            ),
          ),

          // Camera mode indicator
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isFrontCamera ? '📷 Front Camera' : '📷 Rear Camera',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewWidget() {
    return Stack(
      children: [
        // Captured Image
        Positioned.fill(
          child: Image.memory(
            base64Decode(_capturedImageBase64!.split(',').last),
            fit: BoxFit.contain,
          ),
        ),

        // Action buttons
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Retake button
              GestureDetector(
                onTap: _retakePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Retake',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Confirm button
              GestureDetector(
                onTap: _confirmPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Save Receipt',
                        style: GoogleFonts.inter(
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
        ),
      ],
    );
  }
}
