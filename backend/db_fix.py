import mysql.connector

db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Esra123*', 
    'database': 'gezintoo_db'
}

def fix_database():
    try:
        print("🔧 Veritabanı onarımı başlatılıyor...")
        # buffered=True diyerek bu hatayı engelliyoruz
        conn = mysql.connector.connect(buffered=True, **db_config)
        cursor = conn.cursor()

        # 1. 'rating' sütununu kontrol et
        try:
            cursor.execute("SELECT rating FROM places LIMIT 1")
            cursor.fetchall() # Cevabı okuyup temizliyoruz
            print("✅ 'rating' sütunu zaten var.")
        except:
            print("⚠️ 'rating' sütunu bulunamadı, ekleniyor...")
            cursor.execute("ALTER TABLE places ADD COLUMN rating DOUBLE DEFAULT 0.0")
            print("✅ 'rating' eklendi.")

        # 2. 'google_place_id' sütununu kontrol et
        try:
            cursor.execute("SELECT google_place_id FROM places LIMIT 1")
            cursor.fetchall() # Cevabı okuyup temizliyoruz
            print("✅ 'google_place_id' sütunu zaten var.")
        except:
            print("⚠️ 'google_place_id' sütunu bulunamadı, ekleniyor...")
            cursor.execute("ALTER TABLE places ADD COLUMN google_place_id VARCHAR(255)")
            print("✅ 'google_place_id' eklendi.")

        conn.commit()
        cursor.close()
        conn.close()
        print("🎉 Veritabanı başarıyla onarıldı! Şimdi server.py'yi çalıştırabilirsin.")

    except Exception as e:
        print(f"❌ Hata oluştu: {e}")

if __name__ == "__main__":
    fix_database()