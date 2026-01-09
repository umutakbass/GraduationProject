import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/place.dart';

class PlaceService {
  final String baseUrl = "http://10.0.2.2:5000";

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  // 🌍 NORMAL KATEGORİLER (Yemek / Otel / Tarihi)
  Future<List<Place>> fetchPlacesFromOSM(String category) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: _headers,
        body: jsonEncode({
          "mode": "fetch",
          "category": category,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['places'] != null) {
        return (data['places'] as List)
            .map((e) => Place.fromJson(e))
            .toList();
      }
    } catch (e) {
      print("OSM hata: $e");
    }
    return [];
  }

  // ⭐ FAVORİLER & ✔️ GEZDİKLERİM (SADECE USER DATA)
  Future<List<Place>> getUserPlacesByType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId == null) return [];

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_user_places'),
        headers: _headers,
        body: jsonEncode({
          "user_id": userId,
          "type": type, // favorite / visited
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['places'] != null) {
        return (data['places'] as List)
            .map((e) => Place.fromJson(e))
            .toList();
      }
    } catch (e) {
      print("User place hata: $e");
    }
    return [];
  }
}
