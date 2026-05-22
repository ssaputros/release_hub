import sys
from PIL import Image

def optimize_icon(input_path, output_path, padding_percent=0.15, size=1024):
    try:
        # Buka gambar dan ubah ke mode RGBA (jika belum) untuk mendeteksi transparansi
        img = Image.open(input_path).convert("RGBA")
        
        # Dapatkan kotak pembatas (bounding box) untuk membuang transparansi ekstra di sekitar logo
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        
        # Hitung ukuran target untuk logo (mengurangi padding dari kedua sisi)
        # padding 15% di kiri dan kanan berarti logo mengambil 70% dari lebar total
        logo_ratio = 1.0 - (padding_percent * 2)
        target_logo_size = int(size * logo_ratio)
        
        # Pertahankan aspect ratio dari logo aslinya
        aspect = img.width / img.height
        if aspect > 1:
            new_w = target_logo_size
            new_h = int(target_logo_size / aspect)
        else:
            new_h = target_logo_size
            new_w = int(target_logo_size * aspect)
            
        # Resize logo dengan kualitas tinggi (LANCZOS)
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Buat background putih (RGB) dengan ukuran 1024x1024
        background = Image.new('RGB', (size, size), (255, 255, 255))
        
        # Hitung titik tengah untuk menempelkan logo
        offset_x = (size - new_w) // 2
        offset_y = (size - new_h) // 2
        
        # Tempelkan logo ke background putih. 'img' digunakan sebagai mask transparansi
        background.paste(img, (offset_x, offset_y), img)
        
        # Simpan sebagai PNG
        background.save(output_path, 'PNG')
        print(f"✓ Icon berhasil di-optimize (ukuran {size}x{size}, padding ~{int(padding_percent*100)}%, white bg)")
    except Exception as e:
        print(f"❌ Gagal memproses icon: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 optimize_icon.py <input_path> <output_path>")
        sys.exit(1)
    
    optimize_icon(sys.argv[1], sys.argv[2])
