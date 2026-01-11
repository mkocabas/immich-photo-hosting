# Kiliclar Fotoğraf Yükleme Rehberi (rclone - İleri Düzey)

Bu rehber, çok sayıda fotoğraf yüklemek isteyen teknik kullanıcılar içindir. rclone kullanarak daha hızlı ve güvenilir yükleme yapabilirsiniz.

## rclone Nedir?

rclone, bulut depolama servisleriyle çalışmak için kullanılan bir komut satırı aracıdır. Avantajları:
- Çok hızlı toplu yükleme
- Yarıda kalan yüklemeleri devam ettirme
- Otomatik hata düzeltme
- Klasör senkronizasyonu

## Kurulum

### Windows

1. https://rclone.org/downloads/ adresinden Windows sürümünü indirin
2. ZIP dosyasını açın
3. `rclone.exe` dosyasını `C:\rclone\` klasörüne kopyalayın
4. Sistem PATH'ine ekleyin (isteğe bağlı)

### macOS

```bash
brew install rclone
```

veya

```bash
curl https://rclone.org/install.sh | sudo bash
```

### Linux

```bash
curl https://rclone.org/install.sh | sudo bash
```

## Yapılandırma

### Adım 1: Yapılandırma Dosyası Oluşturma

rclone yapılandırma dosyasını açın:

**Windows:** `C:\Users\KULLANICI_ADI\.config\rclone\rclone.conf`
**macOS/Linux:** `~/.config/rclone/rclone.conf`

Aşağıdaki içeriği ekleyin (bilgiler size ayrıca gönderilecektir):

```ini
[kiliclar-b2]
type = b2
account = HESAP_ID_BURAYA
key = UYGULAMA_ANAHTARI_BURAYA
```

### Adım 2: Bağlantıyı Test Etme

```bash
rclone lsd kiliclar-b2:kiliclar-photos-collection
```

Klasör listesi görüyorsanız bağlantı başarılı!

## Fotoğraf Yükleme

### Tek Klasör Yükleme

```bash
rclone copy ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ISMINIZ/
```

**Örnek:**
```bash
rclone copy ~/Pictures/2023-yaz kiliclar-b2:kiliclar-photos-collection/mehmet/2023-yaz/
```

### İlerleme Göstergesi ile Yükleme

```bash
rclone copy ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ISMINIZ/ --progress
```

### Hızlı Yükleme (Paralel Transfer)

```bash
rclone copy ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ISMINIZ/ \
    --progress \
    --transfers 16 \
    --checkers 32
```

### Sadece Belirli Dosya Türlerini Yükleme

```bash
rclone copy ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ISMINIZ/ \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.heic" \
    --include "*.mp4" \
    --include "*.mov" \
    --progress
```

## Yarıda Kalan Yüklemeleri Devam Ettirme

rclone otomatik olarak yarıda kalan yüklemeleri algılar ve devam ettirir. Aynı komutu tekrar çalıştırmanız yeterli.

## Senkronizasyon (İki Yönlü)

**DİKKAT:** Bu komut hedef klasördeki ekstra dosyaları siler!

```bash
rclone sync ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ISMINIZ/ --progress
```

## Faydalı Komutlar

### Yüklenen Dosyaları Listeleme

```bash
rclone ls kiliclar-b2:kiliclar-photos-collection/ISMINIZ/
```

### Klasör Boyutunu Görme

```bash
rclone size kiliclar-b2:kiliclar-photos-collection/ISMINIZ/
```

### Dosya Sayısını Görme

```bash
rclone size kiliclar-b2:kiliclar-photos-collection/ISMINIZ/ --json
```

## Sorun Giderme

### "Access denied" hatası

Yapılandırma dosyasındaki `account` ve `key` değerlerini kontrol edin.

### Yükleme çok yavaş

`--transfers` değerini artırın:
```bash
rclone copy ... --transfers 32
```

### Bağlantı kopuyor

`--retries` parametresi ekleyin:
```bash
rclone copy ... --retries 10 --retries-sleep 5s
```

## Örnek Senaryo

**10.000 fotoğraflık bir klasörü yüklemek:**

```bash
# Önce ne kadar veri olduğunu kontrol edelim
du -sh ~/Fotograflar

# Yüklemeyi başlatalım (arka planda çalışsın)
nohup rclone copy ~/Fotograflar kiliclar-b2:kiliclar-photos-collection/ali/ \
    --progress \
    --transfers 16 \
    --checkers 32 \
    --log-file ~/rclone-upload.log \
    --log-level INFO &

# İlerlemeyi takip edelim
tail -f ~/rclone-upload.log
```

## Yardım

Sorun yaşarsanız WhatsApp grubundan destek isteyebilirsiniz.

---

**Not:** rclone yapılandırma bilgileri (account ID ve key) size özel olarak gönderilecektir. Bu bilgileri kimseyle paylaşmayın!
