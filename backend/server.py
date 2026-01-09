# -*- coding: utf-8 -*-
from waitress import serve
from flask import Flask, request, jsonify
import mysql.connector
from werkzeug.security import generate_password_hash, check_password_hash
import math
import requests
import string
import sys
import json
import re  # ✅ EKLENDİ (intent sırası + doğru eşleşme için)

# Türkçe karakter ve konsol ayarı
try:
    sys.stdout.reconfigure(encoding='utf-8')
except:
    pass

app = Flask(__name__)

# ===================== AYARLAR =====================
GOOGLE_API_KEY = "AIzaSyCAmwE0p9cB27MJEu-D5ykalk7VEpfLWp8"
START_LAT = 37.7765
START_LON = 29.0864

# MySQL Ayarları
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Esra123*',
    'database': 'gezintoo_db'
}

def get_db_connection():
    try:
        return mysql.connector.connect(**db_config)
    except mysql.connector.Error as err:
        print(f"Veritabanı Bağlantı Hatası: {err}")
        return None

def safe_print(text):
    try:
        clean_text = str(text).encode('ascii', 'ignore').decode('ascii')
        print(clean_text)
    except:
        pass

# ===================== 1. BÖLÜM: YARDIMCI FONKSİYONLAR =====================

def normalize_turkish(text):
    """Metinleri eşleştirmek için tertemiz hale getirir (küçük harf, türkçe karakter yok)"""
    if not text:
        return ""
    text = str(text).lower().strip()
    replacements = {'ş': 's', 'ı': 'i', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
                    'Ş': 's', 'İ': 'i', 'Ğ': 'g', 'Ü': 'u', 'Ö': 'o', 'Ç': 'c'}
    for search, replace in replacements.items():
        text = text.replace(search, replace)
    text = text.translate(str.maketrans('', '', string.punctuation))
    return text

def calculate_distance(lat1, lon1, lat2, lon2):
    try:
        if None in [lat1, lon1, lat2, lon2]:
            return 9999.0
        lat1, lon1 = float(lat1), float(lon1)
        lat2, lon2 = float(lat2), float(lon2)
        R = 6371
        dLat = math.radians(lat2 - lat1)
        dLon = math.radians(lon2 - lon1)
        a = math.sin(dLat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c
    except:
        return 0.0

def calculate_level_info(visited_count):
    """
    Kullanıcının gezdiği yer sayısına göre level bilgisi döner
    """
    if visited_count >= 20:
        return {
            "level_id": 4,
            "level_name": "Usta Gezgin",
            "next_level_target": None
        }
    elif visited_count >= 10:
        return {
            "level_id": 3,
            "level_name": "Kaşif",
            "next_level_target": 20
        }
    elif visited_count >= 5:
        return {
            "level_id": 2,
            "level_name": "Gezgin",
            "next_level_target": 10
        }
    else:
        return {
            "level_id": 1,
            "level_name": "Çaylak",
            "next_level_target": 5
        }

def get_progress_text(visited_count):
    """
    Kullanıcının bir sonraki levele ilerlemesini '1/5 Gezgin olmaya' gibi döndürür.
    """
    if visited_count < 5:
        return f"{visited_count}/5 Gezgin olmaya"
    elif visited_count < 10:
        return f"{visited_count-5}/5 Kaşif olmaya"
    elif visited_count < 20:
        return f"{visited_count-10}/10 Usta Gezgin olmaya"
    else:
        return "Maksimum seviyedesin!"

def sort_group_internally(places, start_lat, start_lon):
    if not places:
        return [], start_lat, start_lon
    sorted_places = []
    current_lat, current_lon = float(start_lat), float(start_lon)
    remaining_places = places.copy()

    while remaining_places:
        nearest_place = None
        min_dist = float('inf')
        for place in remaining_places:
            dist = calculate_distance(current_lat, current_lon, place['latitude'], place['longitude'])
            if dist < min_dist:
                min_dist = dist
                nearest_place = place

        if nearest_place:
            sorted_places.append(nearest_place)
            remaining_places.remove(nearest_place)
            current_lat = float(nearest_place['latitude'])
            current_lon = float(nearest_place['longitude'])

    return sorted_places, current_lat, current_lon

def get_google_travel_times(lat1, lon1, lat2, lon2):
    try:
        url = "https://maps.googleapis.com/maps/api/directions/json"
        result = {"drive": "Bilinmiyor", "walk": "Bilinmiyor"}

        # 🚗 ARABA
        params_drive = {
            "origin": f"{lat1},{lon1}",
            "destination": f"{lat2},{lon2}",
            "mode": "driving",
            "language": "tr",
            "key": GOOGLE_API_KEY
        }
        r_drive = requests.get(url, params=params_drive, timeout=5).json()
        if r_drive.get("status") == "OK":
            result["drive"] = r_drive["routes"][0]["legs"][0]["duration"]["text"]

        # 🚶 YÜRÜME
        params_walk = {
            "origin": f"{lat1},{lon1}",
            "destination": f"{lat2},{lon2}",
            "mode": "walking",
            "language": "tr",
            "key": GOOGLE_API_KEY
        }
        r_walk = requests.get(url, params=params_walk, timeout=5).json()
        if r_walk.get("status") == "OK":
            result["walk"] = r_walk["routes"][0]["legs"][0]["duration"]["text"]

        return result
    except:
        return {"drive": "Bilinmiyor", "walk": "Bilinmiyor"}


# ===================== ✅ INTENT (SIRA + KAHVE FIX) =====================

def analyze_flow_intent(user_query):
    """
    ✅ Cümle içinde geçen intentleri, cümlede geçme sırasına göre döndürür.
    ✅ 'kahv' -> 'kahvaltı' içinden yanlış eşleşmesin diye: \\bkahv(?!alt)
    ✅ Dönen her elemana step_order ekler (chat içinde sıra asla bozulmaz).
    """
    try:
        normalized_query = normalize_turkish(user_query)

        mappings = [
            # 🥐 KAHVALTI
            {
                "root": "kahvalt",
                "keyword": "Kahvaltı",
                "api_type": "restaurant",
                "search_query": "serpme kahvaltı",
                "display_name": "Kahvaltı"
            },

            # ☕ KAHVE / KAFE
            {
                "root": "kahv",
                "keyword": "Kahve",
                "api_type": "cafe",
                "search_query": "kahve cafe",
                "display_name": "Kahve"
            },
            {
                "root": "kaf",
                "keyword": "Kahve",
                "api_type": "cafe",
                "search_query": "kahve cafe",
                "display_name": "Kahve"
            },
            {
                "root": "cafe",
                "keyword": "Kahve",
                "api_type": "cafe",
                "search_query": "coffee shop cafe",
                "display_name": "Kahve"
            },

            # 🍽️ YEMEK
            {
                "root": "ogle",
                "keyword": "Yemek",
                "api_type": "restaurant",
                "search_query": "esnaf lokantası",
                "display_name": "Öğle Yemeği"
            },
            {
                "root": "aksam",
                "keyword": "Yemek",
                "api_type": "restaurant",
                "search_query": "akşam yemeği restoran",
                "display_name": "Akşam Yemeği"
            },
            {
                "root": "yemek",
                "keyword": "Yemek",
                "api_type": "restaurant",
                "search_query": "restoran",
                "display_name": "Yemek"
            },

            # 🏨 OTEL
            {
                "root": "otel",
                "keyword": "Otel",
                "api_type": "lodging",
                "search_query": "otel",
                "display_name": "Otel"
            },

            # 🏛️ TARİHİ
            {
                "root": "tarih",
                "keyword": "Tarihi Yer",
                "api_type": "tourist_attraction",
                "search_query": "tarihi yerler",
                "display_name": "Tarihi Yer"
            },
            {
                "root": "muze",
                "keyword": "Tarihi Yer",
                "api_type": "museum",
                "search_query": "müze",
                "display_name": "Müze"
            },
            {
                "root": "gez",
                "keyword": "Gezilecek Yer",
                "api_type": "tourist_attraction",
                "search_query": "gezilecek yerler",
                "display_name": "Gezi"
            },

            # 🛍️ AVM
            {
                "root": "avm",
                "keyword": "Alışveriş",
                "api_type": "shopping_mall",
                "search_query": "alışveriş merkezi",
                "display_name": "AVM"
            },
        ]

        def first_index_for_root(root: str) -> int:
            # ✅ kahv kahvaltıdan eşleşmesin:
            if root == "kahv":
                pattern = r"\bkahv(?!alt)"
            else:
                pattern = r"\b" + re.escape(root)
            m = re.search(pattern, normalized_query)
            return m.start() if m else -1

        matches = []
        for mapping in mappings:
            idx = first_index_for_root(mapping["root"])
            if idx != -1:
                matches.append((idx, mapping))

        matches.sort(key=lambda x: x[0])

        detected_flow = []
        seen = set()
        step_no = 1
        for _, mapping in matches:
            if mapping["display_name"] in seen:
                continue
            step = mapping.copy()
            step["step_order"] = step_no  # ✅ sıra burada kilitleniyor
            detected_flow.append(step)
            seen.add(mapping["display_name"])
            step_no += 1

        return detected_flow

    except Exception as e:
        print("Intent parse hatası:", e)
        return []


# ===================== 2. BÖLÜM: AUTH & DB =====================

@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.json
        name = data.get('name', '').strip()
        email = data.get('email', '').strip()
        password = data.get('password', '').strip()

        if not name or not email or not password:
            return jsonify({"success": False, "message": "Lütfen tüm alanları doldurun!"})

        if "@" not in email or "." not in email:
            return jsonify({"success": False, "message": "Geçersiz e-posta adresi! (@ içermeli)"})

        if len(password) < 6:
            return jsonify({"success": False, "message": "Şifre en az 6 karakter olmalıdır!"})

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            return jsonify({"success": False, "message": "Bu e-posta adresi zaten kayıtlı!"})

        hashed_pw = generate_password_hash(password)

        cursor.execute(
            "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)",
            (name, email, hashed_pw)
        )
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"success": True, "message": "Kayıt başarılı!"})

    except Exception as e:
        return jsonify({"success": False, "message": f"Sunucu Hatası: {str(e)}"})

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        email, password = data.get('email'), data.get('password')
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        conn.close()

        if user and check_password_hash(user['password'], password):
            return jsonify({"success": True, "user": {"id": user['id'], "name": user['name'], "email": user['email']}})
        return jsonify({"success": False, "message": "Hatalı giriş!"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ===================== 3. BÖLÜM: ETKİLEŞİM =====================

@app.route('/add_interaction', methods=['POST'])
def add_interaction():
    try:
        data = request.json
        user_id = data.get('user_id') or 1
        place = data.get('place') if data.get('place') else data
        i_type = data.get('type')  # favorite / visited
        status = data.get('status')

        g_place_id = place.get('google_place_id') or place.get('googlePlaceId')

        status_val = 1
        if str(status).lower() in ['false', '0']:
            status_val = 0
        if isinstance(status, bool) and not status:
            status_val = 0

        print(f"💾 KAYIT: User:{user_id} | MekanID:{g_place_id} | Durum:{status_val} | Tip:{i_type}")

        conn = get_db_connection()
        cursor = conn.cursor()

        if g_place_id:
            cursor.execute("SELECT id FROM places WHERE user_id=%s AND google_place_id=%s", (user_id, g_place_id))
        else:
            cursor.execute("SELECT id FROM places WHERE user_id=%s AND title=%s", (user_id, place.get('title')))

        existing = cursor.fetchone()

        if existing:
            col = "is_liked" if i_type == 'favorite' else "is_visited"
            cursor.execute(f"UPDATE places SET {col}=%s WHERE id=%s", (status_val, existing[0]))
        else:
            if status_val == 1:
                liked = 1 if i_type == 'favorite' else 0
                visited = 1 if i_type == 'visited' else 0

                img_path = place.get('imagePath') or place.get('image_path') or ''
                final_g_id = g_place_id if g_place_id else f"manual_{place.get('title')}"

                sql = """INSERT INTO places
                        (user_id, google_place_id, title, description, location, latitude, longitude, category, image_path, is_liked, is_visited, rating)
                         VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""

                val = (
                    user_id, final_g_id, place.get('title'),
                    place.get('description', ''), place.get('location', ''),
                    place.get('latitude', 0), place.get('longitude', 0),
                    place.get('category', 'genel'),
                    img_path, liked, visited, place.get('rating', 0.0)
                )
                cursor.execute(sql, val)

        conn.commit()

        gamification = None
        if i_type == 'visited' and status_val == 1:
            cursor.execute("SELECT COUNT(*) FROM places WHERE user_id=%s AND is_visited=1", (user_id,))
            visited_count = cursor.fetchone()[0]

            level_info = calculate_level_info(visited_count)
            is_level_up = visited_count in [5, 10, 20]

            if visited_count == 1:
                message = "🏁 İlk Adım! İlk yerini gezdin."
            elif is_level_up:
                message = f"🎉 Tebrikler! {level_info['level_name']} seviyesine ulaştın!"
            else:
                message = f"⏳ {get_progress_text(visited_count)}"

            gamification = {
                "show_notification": True,
                "message": message,
                "is_level_up": is_level_up,
                "level": level_info["level_name"],
                "level_id": level_info["level_id"],
                "visited_count": visited_count,
                "next_remaining": (level_info["next_level_target"] - visited_count) if level_info["next_level_target"] else 0,
                "progress_text": get_progress_text(visited_count)
            }

        cursor.close()
        conn.close()

        response = {"success": True}
        if gamification:
            response["gamification"] = gamification
        return jsonify(response)

    except Exception as e:
        safe_print(f"Hata: {e}")
        return jsonify({"success": False, "message": str(e)})

@app.route('/get_user_places', methods=['POST'])
def get_user_places():
    try:
        data = request.json
        user_id = data.get('user_id') or 1
        i_type = data.get('type')
        col = "is_liked" if i_type == 'favorite' else "is_visited"

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(f"SELECT * FROM places WHERE user_id=%s AND {col}=1", (user_id,))
        res = cursor.fetchall()

        fixed_places = []
        for p in res:
            p['imagePath'] = p['image_path']
            p['googlePlaceId'] = p['google_place_id']
            p['isLiked'] = p['is_liked']
            p['isVisited'] = p['is_visited']
            fixed_places.append(p)

        conn.close()
        return jsonify({"success": True, "places": fixed_places})
    except:
        return jsonify({"success": False, "places": []})

@app.route('/get_user_profile', methods=['POST'])
def get_user_profile():
    try:
        data = request.json
        user_id = data.get('user_id') or 1
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT name FROM users WHERE id=%s", (user_id,))
        user_rec = cursor.fetchone()
        username = user_rec['name'] if user_rec else "Gezgin"

        cursor.execute("SELECT COUNT(*) as count FROM places WHERE user_id=%s AND is_visited=1", (user_id,))
        row = cursor.fetchone()
        visited_count = row['count'] if row else 0
        conn.close()

        level_info = calculate_level_info(visited_count)

        badges = [
            {"id": 1, "name": "İlk Adım", "icon": "flag", "unlocked": visited_count >= 1},
            {"id": 2, "name": "Gezgin", "icon": "walk", "unlocked": visited_count >= 5},
            {"id": 3, "name": "Kaşif", "icon": "map", "unlocked": visited_count >= 10},
            {"id": 4, "name": "Usta Gezgin", "icon": "mountain", "unlocked": visited_count >= 20},
        ]

        return jsonify({
            "success": True,
            "profile": {
                "username": username,
                "title": level_info["level_name"],
                "level": level_info["level_id"],
                "visited_count": visited_count,
                "next_remaining": (level_info["next_level_target"] - visited_count) if level_info["next_level_target"] else 0,
                "progress_text": get_progress_text(visited_count),
                "badges": badges
            }
        })
    except:
        return jsonify({"success": False, "profile": {}})

@app.route('/get_notifications', methods=['POST'])
def get_notifications():
    try:
        data = request.json
        user_id = data.get('user_id') or 1
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT COUNT(*) as count FROM places WHERE user_id=%s AND is_visited=1", (user_id,))
        visited = cursor.fetchone()['count']
        conn.close()

        notifs = [{"title": "Hoşgeldin!", "message": "Gezintoo'ya hoşgeldin.", "date": "Bugün"}]
        if visited >= 1:
            notifs.append({"title": "Tebrikler!", "message": "İlk mekanını ziyaret ettin!", "date": "Yeni"})
        if visited >= 5:
            notifs.append({"title": "Seviye Atlama", "message": "Gezgin seviyesine ulaştın!", "date": "Yeni"})
        if visited >= 10:
            notifs.append({"title": "Seviye Atlama", "message": "Kaşif seviyesine ulaştın!", "date": "Yeni"})
        if visited >= 20:
            notifs.append({"title": "Seviye Atlama", "message": "Usta Gezgin seviyesine ulaştın!", "date": "Yeni"})

        return jsonify({"success": True, "notifications": notifs})
    except:
        return jsonify({"success": False, "notifications": []})

# ===================== 4. BÖLÜM: CHAT & ROTA =====================

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json or {}
    user_query = data.get('category') or data.get('text') or ''
    user_id = data.get('user_id') or 1

    print(f"🧠 CHAT: User:{user_id} | Sorgu:{user_query}")
    flow_steps = analyze_flow_intent(user_query)

    if not flow_steps:
        flow_steps = [{"api_type": "point_of_interest", "search_query": user_query, "keyword": "Sonuçlar", "display_name": "Sonuçlar", "step_order": 1}]

    user_history_map = {}
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT google_place_id, is_liked, is_visited FROM places WHERE user_id=%s", (user_id,))
            db_places = cursor.fetchall()
            conn.close()

            for p in db_places:
                if p['google_place_id']:
                    user_history_map[p['google_place_id']] = p
    except Exception as e:
        print(f"DB Geçmiş Hatası: {e}")

    timeline_stages = []
    current_ref_lat = START_LAT
    current_ref_lon = START_LON
    global_place_id = 1

    # ✅ enumerate geri geldi ama step_order artık intent’ten geliyor
    for index, step in enumerate(flow_steps):
        step_no = step.get("step_order", index + 1)

        url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        params = {
            "query": f"{step['search_query']} in Denizli",
            "type": step['api_type'],
            "key": GOOGLE_API_KEY,
            "language": "tr",
            "location": f"{current_ref_lat},{current_ref_lon}",
            "radius": 5000
        }

        try:
            response = requests.get(url, params=params)
            results = response.json().get('results', [])
            step_places = []
            sum_lat, sum_lon, count = 0, 0, 0

            for place in results[:10]:
                photo_ref = place.get('photos', [{}])[0].get('photo_reference')
                image_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference={photo_ref}&key={GOOGLE_API_KEY}" if photo_ref else ""
                lat = place.get('geometry', {}).get('location', {}).get('lat')
                lng = place.get('geometry', {}).get('location', {}).get('lng')
                g_id = place.get('place_id')

                sum_lat += lat
                sum_lon += lng
                count += 1

                liked_status = 0
                visited_status = 0

                if g_id and g_id in user_history_map:
                    liked_status = user_history_map[g_id]['is_liked']
                    visited_status = user_history_map[g_id]['is_visited']

                step_places.append({
                    "id": global_place_id,
                    "title": place.get('name'),
                    "description": place.get('formatted_address'),
                    "location": place.get('formatted_address'),
                    "latitude": lat,
                    "longitude": lng,
                    "category": step['keyword'],
                    "image_path": image_url,
                    "imagePath": image_url,
                    "rating": float(place.get('rating', 0.0)),
                    "distance": 0,
                   "step_order": step_no,  # ✅ SIRA ARTIK BOZULMAZ
                    "is_recommended": False,
                    "isRecommended": False,
                    "google_place_id": g_id,
                    "is_liked": liked_status,
                    "is_visited": visited_status
                })
                global_place_id += 1

            if count > 0:
                current_ref_lat = sum_lat / count
                current_ref_lon = sum_lon / count

            step_places.sort(key=lambda x: x['rating'], reverse=True)
            for i in range(min(3, len(step_places))):
                step_places[i]['is_recommended'] = True
                step_places[i]['isRecommended'] = True

            timeline_stages.append({
                "step_title": f"{step_no}. Adım: {step.get('display_name', step['keyword'])}",
                "places": step_places
            })

        except Exception as e:
            print(f"API Hatasi: {e}")

    all_places_flattened = []
    for stage in timeline_stages:
        for place in stage['places']:
            p_copy = place.copy()
            p_copy['title'] = f"[{stage['step_title'].split(': ')[1]}] {place['title']}"
            all_places_flattened.append(p_copy)

    # ✅ Flat liste de sırayı korusun (UI karışmasın)
    all_places_flattened.sort(key=lambda x: x.get("step_order", 0))

    step_names = [stage['step_title'].split(": ")[1] for stage in timeline_stages] if timeline_stages else []
    response_text = f"Plan hazır! Sırasıyla:\n" + " ➡️ ".join(step_names) if step_names else "Sonuç bulunamadı."

    return jsonify({
        "status": "selection_ready",
        "mode": "selection",
        "timeline": timeline_stages,
        "places": all_places_flattened,
        "response": response_text
    })

@app.route('/create_route', methods=['POST'])
def create_route():
    try:
        data = request.json or {}
        selected_places = data.get('selected_places', [])

        if not selected_places:
            return jsonify({"success": False, "message": "Mekan yok."})

        # 1️⃣ OLAY SIRASI
        selected_places.sort(key=lambda x: x.get('step_order', 0))

        groups = {}
        for place in selected_places:
            groups.setdefault(place['step_order'], []).append(place)

        sorted_steps = sorted(groups.keys())
        final_route = []
        current_lat, current_lon = START_LAT, START_LON

        # 2️⃣ YAKINLIK OPTİMİZASYONU
        for step in sorted_steps:
            optimized, end_lat, end_lon = sort_group_internally(
                groups[step], current_lat, current_lon
            )
            final_route.extend(optimized)
            current_lat, current_lon = end_lat, end_lon

        # 3️⃣ SÜRE HESAPLAMA (🚗 + 🚶)
        summary_lines = []
        prev_lat, prev_lon = START_LAT, START_LON

        for i, place in enumerate(final_route):
            times = get_google_travel_times(
                prev_lat, prev_lon,
                place['latitude'], place['longitude']
            )

            if i == 0:
                line = (
                    f"1. {place['title']}\n"
                    f"   🚗 Araba: {times['drive']}\n"
                    f"   🚶 Yürüyüş: {times['walk']}"
                )
            else:
                line = (
                    f"{i+1}. {place['title']}\n"
                    f"   🚗 Araba: {times['drive']}\n"
                    f"   🚶 Yürüyüş: {times['walk']}"
                )

            summary_lines.append(line)
            prev_lat = place['latitude']
            prev_lon = place['longitude']

        # 4️⃣ GOOGLE MAPS LİNK
        waypoints = [f"{p['latitude']},{p['longitude']}" for p in final_route]
        maps_url = (
            f"https://www.google.com/maps/dir/?api=1"
            f"&origin={START_LAT},{START_LON}"
            f"&destination={waypoints[-1]}"
            f"&waypoints={'|'.join(waypoints[:-1])}"
            f"&travelmode=driving"
        )

        return jsonify({
            "success": True,
            "optimized_route": final_route,
            "response": "🗺️ Rota Hazır!\n\n" + "\n\n".join(summary_lines),
            "google_maps_url": maps_url
        })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


@app.route('/get_place_details', methods=['POST'])
def get_place_details():
    try:
        data = request.json or {}
        place_id = data.get('place_id')
        user_id = data.get('user_id') or 1

        if not place_id:
            return jsonify({"success": False})

        url = "https://maps.googleapis.com/maps/api/place/details/json"
        params = {"place_id": place_id, "fields": "name,rating,reviews,formatted_phone_number", "language": "tr", "key": GOOGLE_API_KEY}
        resp = requests.get(url, params=params).json().get('result', {})

        user_status = {"is_liked": False, "is_visited": False}

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT is_liked, is_visited FROM places WHERE user_id=%s AND google_place_id=%s", (user_id, place_id))
        row = cursor.fetchone()

        if row:
            user_status['is_liked'] = bool(row['is_liked'])
            user_status['is_visited'] = bool(row['is_visited'])

        conn.close()

        return jsonify({"success": True, "details": resp, "user_status": user_status})
    except Exception as e:
        print(f"Detay Hatası: {e}")
        return jsonify({"success": False})

@app.route('/update_profile_settings', methods=['POST'])
def update_profile_settings():
    conn = None
    try:
        data = request.json
        print(f"DEBUG: Gelen Güncelleme İsteği -> {data}")

        user_id = data.get('user_id')
        new_email = data.get('email', '').strip()
        new_password = data.get('password', '').strip()

        if not user_id or user_id == 0:
            return jsonify({"success": False, "message": "Geçersiz Kullanıcı ID"})

        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "message": "Veritabanı bağlantı hatası"})

        cursor = conn.cursor()

        if new_email and "@" in new_email:
            print(f"DEBUG: Email güncelleniyor -> {new_email}")
            cursor.execute("UPDATE users SET email = %s WHERE id = %s", (new_email, user_id))

        if new_password:
            print(f"DEBUG: Şifre güncelleniyor (Yeni şifre uzunluğu: {len(new_password)})")
            hashed_pw = generate_password_hash(new_password)
            cursor.execute("UPDATE users SET password = %s WHERE id = %s", (hashed_pw, user_id))

        conn.commit()

        if cursor.rowcount == 0:
            print("DEBUG: Hiçbir satır güncellenmedi. ID yanlış olabilir mi?")
            return jsonify({"success": False, "message": "Güncellenecek kullanıcı bulunamadı."})

        cursor.close()
        return jsonify({"success": True, "message": "Bilgiler başarıyla güncellendi!"})

    except Exception as e:
        print(f"SİSTEM HATASI: {str(e)}")
        return jsonify({"success": False, "message": str(e)})
    finally:
        if conn and conn.is_connected():
            conn.close()

if __name__ == '__main__':
    print("🚀 PROJE FINAL (MYSQL MODU): 0.0.0.0:5000")
    serve(app, host='0.0.0.0', port=5000, threads=6)
