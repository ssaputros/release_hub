#!/usr/bin/env python3
import sys
import os
import pexpect

def run_qa_test():
    print("============================================================")
    # Gunakan absolute path agar aman
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    release_sh_path = os.path.join(project_root, "release.sh")
    
    print(f"🤖 MEMULAI SUBAGENT QA UNTUK TESTING MENU DOWNLOAD METADATA")
    print(f"📂 Path release.sh: {release_sh_path}")
    print("============================================================")
    
    # Spawn the interactive bash script
    child = pexpect.spawn(f"bash {release_sh_path}", encoding='utf-8', cwd=project_root)
    child.logfile = sys.stdout  # Stream output to terminal so we can see what's happening
    
    try:
        # Step 1: Tunggu prompt input Project ID
        print("\n[QA] Menunggu prompt Project ID...")
        child.expect("Masukkan Project ID", timeout=15)
        
        # Kirim "1" untuk memilih project pertama
        print("\n[QA] Mengirim input Project ID: 1")
        child.send("1")
        
        # Kirim enter/carriage return untuk mengonfirmasi pilihan project
        print("\n[QA] Mengonfirmasi pilihan project...")
        child.send("\r")
        
        # Step 2: Tunggu prompt pilihan aksi/menu
        print("\n[QA] Menunggu prompt menu aksi...")
        child.expect("Pilihan Anda", timeout=15)
        
        # Kirim "15" untuk mendownload App Store metadata
        print("\n[QA] Mengirim input Menu: 15")
        child.sendline("15")
        
        # Step 3: Tunggu prompt input Bundle ID
        print("\n[QA] Menunggu prompt input Bundle ID...")
        child.expect("Masukkan Bundle ID Aplikasi", timeout=15)
        
        # Kirim Bundle ID spesifik
        print("\n[QA] Mengirim Bundle ID: com.hashmicro.eva.sti")
        child.sendline("com.hashmicro.eva.sti")
        
        # Step 4: Tunggu proses download selesai
        print("\n[QA] Menunggu proses download metadata selesai...")
        # Kita bisa expect pesan sukses atau timeout
        index = child.expect(["Download App Store Metadata selesai dengan sukses!", "❌ Terjadi kesalahan"], timeout=180)
        
        if index == 0:
            print("\n============================================================")
            print("✅ TEST QA BERHASIL: Metadata berhasil didownload!")
            print("============================================================")
            sys.exit(0)
        else:
            print("\n============================================================")
            print("❌ TEST QA GAGAL: Terjadi kesalahan saat mendownload!")
            print("============================================================")
            sys.exit(1)
            
    except pexpect.TIMEOUT:
        print("\n============================================================")
        print("❌ TEST QA TIMEOUT: Proses memakan waktu terlalu lama atau prompt tidak muncul!")
        print("============================================================")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Terjadi error tak terduga: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    run_qa_test()
