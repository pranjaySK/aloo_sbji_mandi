import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  // OpenWeatherMap API - Free tier
  // You can get your API key from https://openweathermap.org/api
  static const String _apiKey = '22a41d3f7f171811dd8149ca3aa42625';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // Default city for fallback
  static const String _defaultCity = 'Agra';

  /// Get current weather by city name
  Future<Map<String, dynamic>> getWeatherByCity(String city) async {
    try {
      final url = Uri.parse('$_baseUrl?q=$city,IN&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherData(data);
      } else {
        print('Weather API error: ${response.statusCode}');
        return _getDefaultWeather();
      }
    } catch (e) {
      print('Error fetching weather by city: $e');
      return _getDefaultWeather();
    }
  }

  /// Get current weather by coordinates
  Future<Map<String, dynamic>> getWeatherByLocation(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherData(data);
      } else {
        print('Weather API error: ${response.statusCode}');
        // Fallback to default city
        return await getWeatherByCity(_defaultCity);
      }
    } catch (e) {
      print('Error fetching weather by location: $e');
      // Fallback to default city
      return await getWeatherByCity(_defaultCity);
    }
  }

  /// Get user's saved city or try to detect location
  Future<Map<String, dynamic>> getWeatherForCurrentLocation() async {
    try {
      // First, try to get saved city from preferences
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('weather_city');

      if (savedCity != null && savedCity.isNotEmpty) {
        return await getWeatherByCity(savedCity);
      }

      // Try to get location via IP (works on web)
      final locationData = await _getLocationFromIP();
      if (locationData != null && locationData['city'] != null) {
        // Save the city for future use
        await prefs.setString('weather_city', locationData['city']);
        return await getWeatherByCity(locationData['city']);
      }

      // Fallback to default city
      return await getWeatherByCity(_defaultCity);
    } catch (e) {
      print('Error getting weather: $e');
      return await getWeatherByCity(_defaultCity);
    }
  }

  /// Get location from IP address (works on web)
  Future<Map<String, dynamic>?> _getLocationFromIP() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://ip-api.com/json/?fields=city,regionName,country'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'city': data['city'],
          'state': data['regionName'],
          'country': data['country'],
        };
      }
    } catch (e) {
      print('IP location error: $e');
    }
    return null;
  }

  /// Parse weather data from API response
  Map<String, dynamic> _parseWeatherData(Map<String, dynamic> data) {
    final main = data['main'] ?? {};
    final weather = (data['weather'] as List?)?.first ?? {};
    final sys = data['sys'] ?? {};

    return {
      'city': data['name'] ?? 'Unknown',
      'state': '', // OpenWeatherMap doesn't return state
      'country': sys['country'] ?? 'IN',
      'temperature': (main['temp'] ?? 0).toDouble(),
      'tempMin': (main['temp_min'] ?? 0).toDouble(),
      'tempMax': (main['temp_max'] ?? 0).toDouble(),
      'humidity': main['humidity'] ?? 0,
      'description': _capitalizeFirst(weather['description'] ?? 'Clear'),
      'icon': weather['icon'] ?? '01d',
      'windSpeed': (data['wind']?['speed'] ?? 0).toDouble(),
      'feelsLike': (main['feels_like'] ?? 0).toDouble(),
      'date': DateTime.now(),
      'isLoaded': true,
    };
  }

  /// Get default weather data when API fails
  Map<String, dynamic> _getDefaultWeather() {
    return {
      'city': 'Your Location',
      'state': '',
      'country': 'India',
      'temperature': 25.0,
      'tempMin': 20.0,
      'tempMax': 30.0,
      'humidity': 60,
      'description': 'Partly Cloudy',
      'icon': '02d',
      'windSpeed': 5.0,
      'feelsLike': 26.0,
      'date': DateTime.now(),
      'isLoaded': false,
    };
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  /// Get weather icon URL
  static String getIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}
