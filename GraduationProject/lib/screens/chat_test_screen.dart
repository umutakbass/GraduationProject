import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // PAKET EKLENDİ
import '../api_service.dart';
import '../models/place.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class ChatTestScreen extends StatefulWidget {
  const ChatTestScreen({super.key});

  @override
  State<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends State<ChatTestScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  // --- YENİ MANTIK DEĞİŞKENLERİ ---
  List<dynamic> _allStages = []; 
  int _currentStageIndex = 0;    

  List<Place> _currentSelectablePlaces = []; 
  List<Place> _tempSelectedPlaces = [];      
  List<Place> _finalRouteList = [];          

  bool _isSelectionMode = false;
  bool _isLoading = false;
  String _currentStepTitle = "";

  // 1. MESAJ GÖNDERME
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"text": text, "isUser": true});
      _resetFlow(); 
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final result = await _apiService.sendMessage(text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (result['success'] == true) {
        if (result['status'] == 'selection_ready' && result['places'] != null) {
           List<Place> allPlaces = result['places'];
           _groupPlacesByStep(allPlaces);
        } else {
           _messages.add({"text": "Sonuç bulunamadı veya anlaşılamadı.", "isUser": false});
        }
      } else {
        _messages.add({"text": "Hata: ${result['response']}", "isUser": false});
      }
    });

    _scrollToBottom();
  }

  void _resetFlow() {
    _isSelectionMode = false;
    _finalRouteList = [];
    _tempSelectedPlaces = [];
    _currentSelectablePlaces = [];
    _allStages = [];
    _currentStageIndex = 0;
  }

  // MEKANLARI ADIMLARA GÖRE GRUPLA
  void _groupPlacesByStep(List<Place> places) {
    places.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    
    Map<int, List<Place>> groups = {};
    for (var p in places) {
      if (!groups.containsKey(p.stepOrder)) {
        groups[p.stepOrder] = [];
      }
      groups[p.stepOrder]!.add(p);
    }

    _allStages = groups.entries.map((e) => e.value).toList();
    
    if (_allStages.isNotEmpty) {
      _startStage(0); 
    } else {
      _messages.add({"text": "Uygun mekan bulunamadı.", "isUser": false});
    }
  }

  // ADIMI BAŞLAT
  void _startStage(int index) {
    setState(() {
      _currentStageIndex = index;
      _currentSelectablePlaces = _allStages[index];
      _tempSelectedPlaces = []; 
      _isSelectionMode = true;
      
      String categoryName = _currentSelectablePlaces.first.category.toUpperCase();
      _currentStepTitle = "${index + 1}. ADIM: $categoryName SEÇİMİ";
      
      _messages.add({"text": "$_currentStepTitle\nLütfen gitmek istediğin yeri seç:", "isUser": false});
    });
    _scrollToBottom();
  }

  void _togglePlaceSelection(Place place) {
    setState(() {
      if (_tempSelectedPlaces.contains(place)) {
        _tempSelectedPlaces.remove(place);
      } else {
        _tempSelectedPlaces.add(place);
      }
    });
  }

  // İLERLE BUTONU
  void _nextStep() {
    if (_tempSelectedPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen en az bir yer seçin!")));
      return;
    }

    setState(() {
      _finalRouteList.addAll(_tempSelectedPlaces);
      String selectedNames = _tempSelectedPlaces.map((e) => e.title).join(", ");
      _messages.add({"text": "✅ Seçildi: $selectedNames", "isUser": true});
    });

    if (_currentStageIndex + 1 < _allStages.length) {
      _startStage(_currentStageIndex + 1);
    } else {
      _createFinalRoute();
    }
  }

  // --- ROTA OLUŞTURMA VE BUTON EKLEME ---
  Future<void> _createFinalRoute() async {
    setState(() {
      _isSelectionMode = false;
      _isLoading = true;
      _messages.add({"text": "Harika! Rota oluşturuluyor...", "isUser": false});
    });

    try {
      final String baseUrl = _apiService.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/create_route'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "selected_places": _finalRouteList.map((e) => {
            "title": e.title,
            "latitude": e.latitude,
            "longitude": e.longitude,
            "step_order": e.stepOrder 
          }).toList()
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      setState(() {
        _isLoading = false;
        if (data['success'] == true) {
           // BURADA LİNKİ GİZLİ ALANA EKLİYORUZ
           _messages.add({
             "text": "${data['response']}", 
             "isUser": false,
             "mapUrl": data['google_maps_url'] // URL Burada saklı
           });
        } else {
           _messages.add({"text": "Rota oluşturulamadı.", "isUser": false});
        }
      });
      _scrollToBottom();
      
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HARİTAYI AÇAN FONKSİYON ---
  Future<void> _launchMaps(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Link açılamadı';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harita uygulaması açılamadı!")));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Akıllı Asistan", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                // Mesajda mapUrl var mı kontrol et
                final hasUrl = msg.containsKey('mapUrl') && msg['mapUrl'] != null && msg['mapUrl'] != "";
                
                return Align(
                  alignment: msg['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: msg['isUser'] ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Mesaj Balonu
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: msg['isUser'] ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(msg['text'], style: TextStyle(color: msg['isUser'] ? Colors.white : Colors.black)),
                      ),
                      
                      // --- URL VARSA BUTON GÖSTER ---
                      if (hasUrl)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: ElevatedButton.icon(
                            onPressed: () => _launchMaps(msg['mapUrl']),
                            icon: const Icon(Icons.map, color: Colors.white),
                            label: const Text("Rotayı Haritada Başlat 🗺️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading) const LinearProgressIndicator(),

          // ADIM ADIM SEÇİM EKRANI
          if (_isSelectionMode)
            Container(
              height: 340,
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_currentStepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                            Text("${_tempSelectedPlaces.length} yer seçildi", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _nextStep,
                          icon: Icon(_currentStageIndex + 1 == _allStages.length ? Icons.map : Icons.arrow_forward, size: 18, color: Colors.white),
                          label: Text(_currentStageIndex + 1 == _allStages.length ? "Rotayı Oluştur" : "Devam Et", style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStageIndex + 1 == _allStages.length ? Colors.green : Colors.blue,
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  // MEKAN LİSTESİ
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _currentSelectablePlaces.length,
                      itemBuilder: (context, index) {
                        final Place place = _currentSelectablePlaces[index];
                        final bool isSelected = _tempSelectedPlaces.contains(place);

                        return GestureDetector(
                          onTap: () => _togglePlaceSelection(place),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 160,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green[50] : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isSelected ? Colors.green : Colors.grey[300]!, width: isSelected ? 2 : 1),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    child: place.imagePath.startsWith("http")
                                        ? Image.network(place.imagePath, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)))
                                        : Image.asset("assets/images/${place.category.toLowerCase()}.jpg", fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[300], child: const Icon(Icons.image))),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(place.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(children: [const Icon(Icons.star, size: 12, color: Colors.orange), Text(" ${place.rating}", style: const TextStyle(fontSize: 11))]),
                                            if (isSelected) const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // MESAJ GİRİŞ ALANI
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "Örn: Kahvaltı yapıp otele gideceğim", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)), onSubmitted: _sendMessage)),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: Colors.blue, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _sendMessage(_controller.text))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}