import mysql.connector
from werkzeug.security import generate_password_hash # <--- BU EKLENDİ

# --- VERİTABANI AYARLARI ---
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Esra123*', 
    'database': 'gezintoo_db'
}

def create_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        return conn
    except mysql.connector.Error as err:
        print(f"Hata: {err}")
        return None

def create_tables(cursor):
    # Kullanıcılar Tablosu
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        email VARCHAR(100) UNIQUE,
        password VARCHAR(255)  -- Hash uzun olacağı için 100 yetmeyebilir, 255 yaptım
    )
    """)

    # Mekanlar Tablosu
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS places (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT,
        title VARCHAR(255),
        description TEXT,
        location VARCHAR(255),
        latitude DOUBLE,
        longitude DOUBLE,
        category VARCHAR(50),
        image_path TEXT,
        is_liked TINYINT(1) DEFAULT 0,
        is_visited TINYINT(1) DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
    """)
    print("✅ Tablolar kontrol edildi/oluşturuldu.")

def insert_dummy_data():
    conn = create_connection()
    if conn is None:
        return

    cursor = conn.cursor()
    create_tables(cursor)

    # 1. ÖNCE TEST KULLANICISI EKLE (Yoksa)
    cursor.execute("SELECT id FROM users WHERE email = 'test@gmail.com'")
    user = cursor.fetchone()
    
    user_id = 1
    if not user:
        # --- KRİTİK DÜZELTME: ŞİFREYİ HASHLEYEREK KAYDEDİYORUZ ---
        hashed_pw = generate_password_hash("123456") 
        
        sql_user = "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)"
        cursor.execute(sql_user, ("Test Kullanıcısı", "test@gmail.com", hashed_pw))
        user_id = cursor.lastrowid
        print(f"👤 Test kullanıcısı oluşturuldu (ID: {user_id}, Şifre: 123456)")
    else:
        user_id = user[0]
        print(f"👤 Test kullanıcısı zaten var (ID: {user_id})")

    # 2. DENİZLİ MEKAN LİSTESİ
    places_data = [
        ("Kebapçı Enver", "Denizli'nin en meşhur tandır kebabı.", "Bayramyeri", 37.7728, 29.0875, "yemek"),
        ("Hierapolis Antik Kenti", "UNESCO Dünya Mirası listesindeki antik kent.", "Pamukkale", 37.9256, 29.1250, "tarih"),
        ("Pamukkale Travertenleri", "Beyaz cennet, doğal termal havuzlar.", "Pamukkale", 37.9245, 29.1235, "gezi"),
        ("Laodikeia Antik Kenti", "İncil'de adı geçen 7 kiliseden biri burada.", "Goncalı", 37.8360, 29.1070, "tarih"),
        ("Hacı Şerif", "Meşhur dondurmalı irmik helvası.", "Merkez", 37.7740, 29.0890, "yemek"),
        ("Bağbaşı Yaylası Teleferik", "Şehri kuşbakışı izlemek için harika bir yer.", "Bağbaşı", 37.7500, 29.1100, "gezi"),
        ("Richmond Thermal Hotel", "Termal suların keyfini çıkarın.", "Karahayıt", 37.9550, 29.1150, "otel"),
        ("Anemon Otel", "Şehir merkezine yakın konforlu konaklama.", "İzmir Yolu", 37.7950, 29.0550, "otel"),
        ("Gazozcu Yusuf", "Efsane Zafer gazozunun en taze hali.", "Çınar", 37.7750, 29.0900, "gazoz"),
        ("Kaklık Mağarası", "Yeraltındaki küçük Pamukkale.", "Kaklık", 37.8500, 29.3500, "gezi"),
        ("Saray Pide", "Denizli usulü kıymalı pide.", "Çınar", 37.7760, 29.0880, "yemek"),
        ("Tripolis Antik Kenti", "Buldan yöresindeki saklı tarih.", "Buldan", 38.0500, 28.9500, "tarih"),
        ("Keloğlan Mağarası", "Sarkıt ve dikitleriyle ünlü mağara.", "Acıpayam", 37.4000, 29.3000, "gezi"),
        ("Şehir Simit Sarayı", "Sabah kahvaltılarının vazgeçilmezi.", "Çınar", 37.7755, 29.0860, "kahvaltı"),
        ("Colossae Thermal", "Beş yıldızlı termal otel deneyimi.", "Karahayıt", 37.9500, 29.1200, "otel"),
    ]

    # 3. VERİLERİ EKLE
    print("⏳ Mekanlar ekleniyor...")
    count = 0
    for place in places_data:
        cursor.execute("SELECT id FROM places WHERE title = %s AND user_id = %s", (place[0], user_id))
        if not cursor.fetchone():
            sql = """INSERT INTO places 
                     (user_id, title, description, location, latitude, longitude, category, image_path, is_liked, is_visited) 
                     VALUES (%s, %s, %s, %s, %s, %s, %s, '', 1, 0)"""
            cursor.execute(sql, (user_id, place[0], place[1], place[2], place[3], place[4], place[5]))
            count += 1
    
    conn.commit()
    print(f"✅ Toplam {count} yeni mekan veritabanına eklendi.")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    insert_dummy_data()