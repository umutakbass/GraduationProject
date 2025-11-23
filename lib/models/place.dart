class Place {
  final int? id;
  final int? userId;
  final String title;
  final String description;
  final String location;
  final String imageName;
  final double latitude;
  final double longitude;
  int isLiked;
  int isVisited;
  
  // YENİ ALANLAR
  String? userNote; 
  double? distance; 
  String? weatherInfo;

  Place({
    this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.location,
    required this.imageName,
    required this.latitude,
    required this.longitude,
    this.isLiked = 0,
    this.isVisited = 0,
    this.userNote,
    this.distance,
    this.weatherInfo,
  });

  Place copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    String? location,
    String? imageName,
    double? latitude,
    double? longitude,
    int? isLiked,
    int? isVisited,
    String? userNote,
    double? distance,
    String? weatherInfo,
  }) {
    return Place(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      imageName: imageName ?? this.imageName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLiked: isLiked ?? this.isLiked,
      isVisited: isVisited ?? this.isVisited,
      userNote: userNote ?? this.userNote,
      distance: distance ?? this.distance,
      weatherInfo: weatherInfo ?? this.weatherInfo,
    );
  }

  factory Place.fromMap(Map<String, dynamic> json) => Place(
        id: json['id'],
        userId: json['userId'],
        title: json['title'],
        description: json['description'],
        location: json['location'],
        imageName: json['imageName'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        isLiked: json['isLiked'],
        isVisited: json['isVisited'] ?? 0,
        userNote: json['userNote'],
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'location': location,
      'imageName': imageName,
      'latitude': latitude,
      'longitude': longitude,
      'isLiked': isLiked,
      'isVisited': isVisited,
      'userNote': userNote,
    };
  }
}