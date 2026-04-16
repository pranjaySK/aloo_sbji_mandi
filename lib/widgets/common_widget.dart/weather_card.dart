import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/service/weather_service.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/utils/ist_datetime.dart';

class WeatherCard extends StatefulWidget {
  final String? city;

  const WeatherCard({super.key, this.city});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  final WeatherService _weatherService = WeatherService();
  Map<String, dynamic> _weatherData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    AppLocalizations.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocalizations.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);

    Map<String, dynamic> data;
    if (widget.city != null && widget.city!.isNotEmpty) {
      data = await _weatherService.getWeatherByCity(widget.city!);
    } else {
      data = await _weatherService.getWeatherForCurrentLocation();
    }

    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date.toIST());
  }

  IconData _getWeatherIcon(String? iconCode) {
    if (iconCode == null) return Icons.wb_sunny;

    if (iconCode.contains('01')) return Icons.wb_sunny;
    if (iconCode.contains('02')) return Icons.wb_cloudy;
    if (iconCode.contains('03') || iconCode.contains('04')) return Icons.cloud;
    if (iconCode.contains('09') || iconCode.contains('10')) return Icons.grain;
    if (iconCode.contains('11')) return Icons.flash_on;
    if (iconCode.contains('13')) return Icons.ac_unit;
    if (iconCode.contains('50')) return Icons.blur_on;

    return Icons.wb_cloudy;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3,
          width: 320,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3C3F), Color(0xFF1FA2A8)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final city = _weatherData['city'] ?? AppLocalizations.tr('your_location');
    final country = _weatherData['country'] ?? 'India';
    final temp = (_weatherData['temperature'] ?? 25).toStringAsFixed(0);
    final tempMin = (_weatherData['tempMin'] ?? 20).toStringAsFixed(0);
    final tempMax = (_weatherData['tempMax'] ?? 30).toStringAsFixed(0);
    final description = _weatherData['description'] ?? 'Partly Cloudy';
    final date = _weatherData['date'] ?? DateTime.now();
    final iconCode = _weatherData['icon'] ?? '02d';
    final humidity = _weatherData['humidity'] ?? 60;
    final windSpeed = (_weatherData['windSpeed'] ?? 5).toStringAsFixed(1);

    return Center(
      child: GestureDetector(
        onTap: _loadWeather,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3,
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3C3F), Color(0xFF1FA2A8)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Location with refresh icon
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$city, $country',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    _getWeatherIcon(iconCode),
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),

              const SizedBox(height: 4),

              /// Date
              Text(
                _formatDate(date),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const SizedBox(height: 14),

              /// Temperature
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$temp°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$humidity%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.air,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$windSpeed m/s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// Min / Max
              Text(
                '${AppLocalizations.tr('weather_max')} $tempMax°C | ${AppLocalizations.tr('weather_min')} $tempMin°C',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 16),

              /// Divider
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.white24,
              ),

              const SizedBox(height: 12),

              /// Weather status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.tr('tap_to_refresh'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
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
}
