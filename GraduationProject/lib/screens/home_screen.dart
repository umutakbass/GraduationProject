import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place.dart';
import 'place_details_screen.dart';
import 'chat_test_screen.dart';
import '../api_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  String selectedType = "otel";
  List<Place> places = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => isLoading = true);

    try {
      List<Place> fetched = [];

      if (selectedType == "favorites") {
        fetched = await _apiService.getUserPlaces();
        fetched = fetched.where((p) => p.isLiked == 1).toList();
      } else if (selectedType == "visited") {
        fetched = await _apiService.getUserPlaces();
        fetched = fetched.where((p) => p.isVisited == 1).toList();
      } else {
        final res = await _apiService.sendMessage(selectedType);
        fetched = (res["places"] as List<Place>);
      }

      setState(() {
        places = fetched;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        places = [];
        isLoading = false;
      });
    }
  }

  void _onChipSelected(String type) {
    if (type == selectedType) return;
    setState(() => selectedType = type);
    _loadPlaces();
  }

  Color _chipColor(String type) {
    switch (type) {
      case "yemek":
        return Colors.orange;
      case "otel":
        return Colors.blue;
      case "cafe":
        return Colors.brown;
      case "tarihi":
        return Colors.purple;
      case "favorites":
        return Colors.red;
      case "visited":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildChip(String label, String type) {
    final isSelected = selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onChipSelected(type),
        selectedColor: _chipColor(type),
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "RoadTo",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildChip("Yemek", "yemek"),
                _buildChip("Otel", "otel"),
                _buildChip("Kafe", "cafe"),
                _buildChip("Turistik", "tarihi"),
                _buildChip("Favoriler", "favorites"),
                _buildChip("Gezdiklerim", "visited"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : places.isEmpty
                    ? const Center(child: Text("Mekan bulunamadı"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaceDetailsScreen(place: place),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
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
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: place.imagePath.startsWith("http")
                                        ? Image.network(
                                            place.imagePath,
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.image),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.title,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                size: 14,
                                                color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(
                                              place.rating.toString(),
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
