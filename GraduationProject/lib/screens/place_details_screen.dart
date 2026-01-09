import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../api_service.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final ApiService _apiService = ApiService();
  
  // Durum değişkenleri
  bool isLiked = false;
  bool isVisited = false;
  
  Set<Marker> _markers = {};
  List<dynamic> reviews = [];
  bool isLoadingDetails = true;
  String phoneNumber = "";
  double googleRating = 0.0;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    // 1. Başlangıçta gelen veriyi (Home'dan veya Favorilerden) kabul et
    isLiked = widget.place.isLiked == 1;
    isVisited = widget.place.isVisited == 1;
    googleRating = widget.place.rating;
    
    _createMarker();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getInt('currentUserId');
    });

    if (currentUserId != null) {
      // Paralel olarak iki işlemi de başlatıyoruz
      Future.wait([
        _fetchPlaceDetails(),       // Detayları (Yorum, Puan) çek
        _checkUserInteractions()    // GARANTİ YÖNTEMİ: Favorileri kontrol et
      ]);
    } else {
      // Kullanıcı giriş yapmamışsa sadece detayları çek
      _fetchPlaceDetails();
    }
  }

  // --- GARANTİ YÖNTEMİ: LİSTE KONTROLÜ ---
  Future<void> _checkUserInteractions() async {
    try {
      // Kullanıcının tüm etkileşimlerini (favori/gezildi) çekiyoruz
      final userPlaces = await _apiService.getUserPlaces();
      
      // Bu mekan (widget.place) listede var mı diye bakıyoruz
      // Hem title hem googlePlaceId kontrolü yapıyoruz ki kaçırma olmasın
      final match = userPlaces.firstWhere(
        (p) => (p.googlePlaceId == widget.place.googlePlaceId) || 
               (p.title == widget.place.title),
        orElse: () => Place(
          title: "", description: "", location: "", 
          latitude: 0, longitude: 0, category: "", imagePath: ""
        ), // Boş obje (match yoksa)
      );

      // Eğer eşleşme bulunduysa ve başlığı doluysa (boş obje değilse)
      if (match.title.isNotEmpty && mounted) {
        setState(() {
          // Backend'den gelen kesin bilgiyi ekrana bas
          if (match.isLiked == 1) isLiked = true;
          if (match.isVisited == 1) isVisited = true;
        });
        debugPrint("✅ Doğrulama Başarılı: Favori/Gezildi durumu güncellendi.");
      }
    } catch (e) {
      debugPrint("Doğrulama Hatası: $e");
    }
  }

  Future<void> _fetchPlaceDetails() async {
    if (widget.place.googlePlaceId == null || widget.place.googlePlaceId!.isEmpty) {
      setState(() => isLoadingDetails = false);
      return;
    }

    try {
      final data = await _apiService.getPlaceDetails(
        widget.place.googlePlaceId!, 
        currentUserId ?? 1
      );

      if (mounted) {
        setState(() {
          if (data['success'] == true) {
            reviews = data['details']['reviews'] ?? [];
            phoneNumber = data['details']['formatted_phone_number'] ?? "";
            
            if (data['details']['rating'] != null) {
              googleRating = (data['details']['rating'] as num).toDouble();
            }
            
            // Eğer detay servisi de status dönüyorsa onu da değerlendir (Yedek kontrol)
            if (data['user_status'] != null) {
              final status = data['user_status'];
              // isLiked zaten true ise (garanti yönteminden geldiyse) dokunma, değilse buraya bak
              if (!isLiked) isLiked = (status['is_liked'] == true || status['is_liked'] == 1);
              if (!isVisited) isVisited = (status['is_visited'] == true || status['is_visited'] == 1);
            }
          }
          isLoadingDetails = false;
        });
      }
    } catch (e) {
      debugPrint("Detay Hata: $e");
      if (mounted) setState(() => isLoadingDetails = false);
    }
  }

  // --- HARİTA MARKER ---
  void _createMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(widget.place.title),
          position: LatLng(widget.place.latitude, widget.place.longitude),
          infoWindow: InfoWindow(title: widget.place.title),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  // --- HARİTA AÇMA ---
  Future<void> _openExternalMap() async {
    final googleUrl = Uri.parse("http://googleusercontent.com/maps.google.com/maps?daddr=${widget.place.latitude},${widget.place.longitude}");
    try {
      if (!await launchUrl(googleUrl, mode: LaunchMode.externalApplication)) {
        throw 'Harita başlatılamadı';
      }
    } catch (e) {
      debugPrint("Harita hatası: $e");
    }
  }

  // --- ETKİLEŞİM (FAVORİ/GEZİLDİ) ---
  Future<void> _toggleInteraction(String type) async {
    bool previousStatus = (type == 'favorite') ? isLiked : isVisited;
    bool newStatus = !previousStatus;
    
    // 1. Ekranda anında güncelle (Optimistic UI)
    setState(() {
      if (type == 'favorite') isLiked = newStatus;
      else isVisited = newStatus;
    });

    // 2. Sunucuya gönder
    final response = await _apiService.toggleInteraction(
      userId: currentUserId ?? 1,
      type: type,
      status: newStatus,
      place: widget.place,
      rating: googleRating
    );

    // 3. Başarılı ise bildirim kontrolü, başarısız ise geri al
    if (response['success'] == true) {
      if (type == 'visited' && newStatus == true && response['gamification'] != null) {
        _showGamificationSnackBar(response['gamification']);
      }
    } else {
      debugPrint("❌ İşlem sunucuda başarısız oldu, geri alınıyor.");
      if (mounted) {
        setState(() {
          if (type == 'favorite') isLiked = previousStatus;
          else isVisited = previousStatus;
        });
      }
    }
  }

  void _showGamificationSnackBar(Map<String, dynamic> gameData) {
    if (gameData['show_notification'] == true && mounted) {
      String message = gameData['message'];
      bool isLevelUp = gameData['is_level_up'] ?? false;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isLevelUp ? Icons.emoji_events : Icons.trending_up, 
                color: Colors.white, size: 28
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  message, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)
                )
              ),
            ],
          ),
          backgroundColor: isLevelUp ? Colors.orange[800] : Colors.blue[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // RESİM ALANI
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.blueGrey[100],
            child: widget.place.imagePath.startsWith('http')
                ? Image.network(widget.place.imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50))
                : const Icon(Icons.location_city, size: 100, color: Colors.white),
          ),
          
          // GERİ BUTONU
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // KAYDIRILABİLİR İÇERİK
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ListView(
                  controller: scrollController,
                  children: [
                    // GRİ ÇUBUK
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // BAŞLIK VE FAVORİ BUTONU
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.place.title,
                            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _toggleInteraction('favorite'),
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey, // Renk Değişimi
                            size: 32,
                          ),
                        ),
                      ],
                    ),

                    // PUAN VE KATEGORİ
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text("$googleRating", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.place.category.toUpperCase(),
                          style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    // KONUM
                    Text(
                      widget.place.location,
                      style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                    ),
                    
                    const SizedBox(height: 20),

                    // BUTONLAR: YOL TARİFİ & GEZİLDİ
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openExternalMap,
                            icon: const Icon(Icons.directions, color: Colors.white, size: 20),
                            label: const Text("Yol Tarifi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleInteraction('visited'),
                            icon: Icon(
                              isVisited ? Icons.check_circle : Icons.flag_outlined,
                              color: isVisited ? Colors.white : Colors.blueAccent,
                              size: 20,
                            ),
                            label: Text(
                              isVisited ? "Gezildi" : "Burayı Gezdim",
                              style: TextStyle(
                                color: isVisited ? Colors.white : Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isVisited ? Colors.green : Colors.blueAccent.withOpacity(0.1),
                              elevation: isVisited ? 2 : 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(color: isVisited ? Colors.green : Colors.blueAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    
                    // HARİTA ÖNİZLEME
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(widget.place.latitude, widget.place.longitude),
                            zoom: 15.0,
                          ),
                          markers: _markers,
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                    
                    // AÇIKLAMA
                    Text("Hakkında", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      widget.place.description.isNotEmpty ? widget.place.description : "Bu mekan hakkında henüz detaylı açıklama eklenmemiş.",
                      style: GoogleFonts.poppins(color: Colors.grey[700], height: 1.5, fontSize: 14),
                    ),
                    
                    const SizedBox(height: 25),

                    // YORUMLAR
                    Text("Kullanıcı Yorumları", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    isLoadingDetails
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                        : reviews.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text("Henüz yorum yapılmamış.", style: GoogleFonts.poppins(color: Colors.grey)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: reviews.length,
                                itemBuilder: (context, index) {
                                  final review = reviews[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 0,
                                    color: Colors.grey[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: Colors.grey.shade100),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                                radius: 16,
                                                child: Text(
                                                  (review['author_name'] ?? "A")[0],
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  review['author_name'] ?? "Anonim",
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                              const Icon(Icons.star, color: Colors.amber, size: 14),
                                              const SizedBox(width: 2),
                                              Text("${review['rating']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            review['text'] ?? "",
                                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}