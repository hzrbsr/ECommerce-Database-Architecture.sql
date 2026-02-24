/*
--------------------------------------------------------------------
PROJE ADI: Dinamik ve Otonom E-Ticaret Veritabanı Mimarisi
GELİŞTİRİCİ: Veritabanı Mimarı (13 Günlük SQL Kampı Bitirme Projesi)
AÇIKLAMA: 
Bu proje, modern bir E-Ticaret sisteminin arka planında çalışan 
ilişkisel veritabanı (RDBMS) yapısını simüle eder.

TEMEL ÖZELLİKLER (MÜHENDİSLİK ÇÖZÜMLERİ):
1. Normalizasyon: Siparişler (Orders) ve Sipariş Detayları (OrderDetails) ayrıştırılarak veri tekrarı önlenmiştir.
2. Otomasyon (Triggers): Satış yapıldığı anda stok düşme işlemi Set-Based Trigger ile otonom hale getirilmiştir.
3. NoSQL Esnekliği (JSON): Ürünlerin farklı özelliklerini (Beden, Switch, Renk vb.) tek bir tabloda 
   esnek bir şekilde tutabilmek için JSON veri yapısı entegre edilmiştir.
4. Veri Bütünlüğü: Email benzersizliği (UNIQUE), aktif/pasif durumları (BIT, DEFAULT) kısıtlamalarla güvenceye alınmıştır.
--------------------------------------------------------------------
*/

-- =========================================
-- 1. TABLOLARIN OLUŞTURULMASI (DDL İşlemleri)
-- =========================================

-- Kullanıcılar ve Güvenlik
CREATE TABLE Users (
    ID INT PRIMARY KEY IDENTITY (1,1),
    AdSoyad NVARCHAR(50),
    Email NVARCHAR(50) UNIQUE, -- Aynı e-posta ile iki kez kayıt olunamaz
    Sifre NVARCHAR(256) NOT NULL, -- Şifrelenmiş (Hash) metinler için uzun alan
    KullaniciRolu BIT DEFAULT 0, -- 0: Müşteri, 1: Admin
    HesapDurumu BIT DEFAULT 1, -- 1: Aktif, 0: Pasif
    KayitTarihi DATETIME DEFAULT GETDATE() -- Otomatik zaman damgası
);
GO

-- Kategori Yönetimi
CREATE TABLE Categories (
    KategoriID INT PRIMARY KEY IDENTITY(1,1),
    KategoriAdi NVARCHAR(30),
    AktifMi BIT DEFAULT 1
);
GO

-- Ürünler ve Esnek JSON Mimarisi
CREATE TABLE Products (
    UrunID INT PRIMARY KEY IDENTITY (1,1),
    UrunAdi NVARCHAR(30),
    Fiyat DECIMAL(18,2), -- Hassas para birimleri için DECIMAL
    Stok INT,
    KategoriID INT FOREIGN KEY REFERENCES Categories(KategoriID),
    OzelliklerJson NVARCHAR(MAX) -- Her ürüne özel dinamik nitelikler için JSON kolonu
);
GO

-- Sipariş Faturası (Üst Bilgi)
CREATE TABLE Orders (
    SiparisID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT FOREIGN KEY REFERENCES Users(ID),
    ToplamTutar DECIMAL(18,2),
    SiparisTarihi DATETIME DEFAULT GETDATE(),
    Durum NVARCHAR(30) DEFAULT 'Onaylandı'
);
GO

-- Sepet Detayları (Alt Bilgi)
CREATE TABLE OrderDetails (
    DetayID INT PRIMARY KEY IDENTITY(1,1),
    SiparisID INT FOREIGN KEY REFERENCES Orders(SiparisID),
    UrunID INT FOREIGN KEY REFERENCES Products(UrunID),
    Adet INT,
    BirimFiyat DECIMAL(18,2) -- Fiyatın satıldığı anki halini mühürlemek için
);
GO

-- =========================================
-- 2. YAPAY ZEKA & OTOMASYON (Triggers)
-- =========================================

-- Sipariş girildiğinde (INSERT), satılan ürünlerin stoğunu otonom olarak düşen Set-Based Trigger
CREATE TRIGGER trg_StokYonetimi
ON OrderDetails
AFTER INSERT
AS
BEGIN
    -- Döngü (Cursor) kullanmadan, arka plandaki "inserted" tablosu ile ana tabloyu eşleştirerek (JOIN) performansı maksimize ediyoruz.
    UPDATE P
    SET P.Stok = P.Stok - I.Adet
    FROM Products P
    INNER JOIN inserted I ON P.UrunID = I.UrunID;
END;
GO

-- =========================================
-- 3. TEST VERİSİ GİRİŞİ (DML İşlemleri)
-- =========================================

-- Ebeveyn tabloları dolduruyoruz
INSERT INTO Categories (KategoriAdi, AktifMi)
VALUES ('Elektronik', 1), ('Giyim', 1);

-- Başlangıçta 100'er adet stok giriyoruz
INSERT INTO Products (UrunAdi, Fiyat, Stok, KategoriID)
VALUES ('Klavye', 150.00, 100, 1), 
       ('Kazak', 100.00, 100, 2);

INSERT INTO Users (AdSoyad, Email, Sifre, KullaniciRolu, HesapDurumu)
VALUES ('Hazar Başar', 'hazar.121@gmail.com', 'hashed_password_123', 0, 1);
GO

-- =========================================
-- 4. JSON ENTEGRASYONU VE ESNEK GÜNCELLEMELER
-- =========================================

-- Ürünlere yapısal olarak birbirinden tamamen farklı özellikler atıyoruz
UPDATE Products
SET OzelliklerJson = '{"Renk": "Siyah", "Switch": "Mekanik", "Dil": "TR"}'
WHERE UrunID = 1;

UPDATE Products
SET OzelliklerJson = '{"Beden": "L", "Kumas": "Pamuk"}'
WHERE UrunID = 2;
GO

-- =========================================
-- 5. SİSTEM TESTİ VE RAPORLAMA
-- =========================================

-- SENARYO: Hazar, 2 Klavye ve 1 Kazak satın alır.
INSERT INTO Orders (UserID, ToplamTutar, Durum)
VALUES (1, 400.00, 'Onaylandı');

-- Multi-row insert ile tek seferde sepeti onaylıyoruz (Trigger bu anda uyanır)
INSERT INTO OrderDetails (SiparisID, UrunID, Adet, BirimFiyat)
VALUES (1, 1, 2, 150.00),
       (1, 2, 1, 100.00);
GO

-- RAPOR 1: Stokların otonom olarak düştüğünün kanıtı
SELECT UrunAdi, Stok AS GuncelStok 
FROM Products;

-- RAPOR 2: JSON kolonunun içinden cımbızla (JSON_VALUE) belirli bir özelliği (Switch tipini) çekme
SELECT 
    UrunAdi, 
    Fiyat, 
    JSON_VALUE(OzelliklerJson, '$.Switch') AS KlavyeTuru
FROM Products
WHERE KategoriID = 1;
GO
