#!/usr/bin/env python3
import sys
import os
import pexpect
import argparse

def run_qa_test():
    parser = argparse.ArgumentParser(description="Subagent QA CLI Tester")
    parser.add_argument("--menu", type=int, default=15, choices=[15, 17], help="Menu number to test (15 = App Store, 17 = Play Store)")
    parser.add_argument("--id", type=str, default="com.hashmicro.eva.sti", help="Bundle ID or Package Name")
    args = parser.parse_args()

    print("============================================================")
    # Gunakan absolute path agar aman
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    release_sh_path = os.path.join(project_root, "release.sh")
    
    print(f"🤖 MEMULAI SUBAGENT QA UNTUK TESTING MENU DOWNLOAD METADATA")
    print(f"📂 Path release.sh: {release_sh_path}")
    print(f"📌 Menu: {args.menu}")
    print(f"📌 ID  : {args.id}")
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
        
        # Kirim pilihan menu
        print(f"\n[QA] Mengirim input Menu: {args.menu}")
        child.sendline(str(args.menu))
        
        # Step 3: Tunggu prompt input ID (Bundle ID / Package Name)
        print("\n[QA] Menunggu prompt input ID...")
        if args.menu == 15:
            child.expect("Masukkan Bundle ID Aplikasi", timeout=15)
        else:
            child.expect("Masukkan Package Name Aplikasi", timeout=15)
        
        # Kirim ID spesifik
        print(f"\n[QA] Mengirim ID: {args.id}")
        child.sendline(args.id)
        

        
        # Step 4: Tunggu proses download selesai
        print("\n[QA] Menunggu proses download metadata selesai...")
        
        success_phrases = [
            "Download App Store Metadata selesai dengan sukses!",
            "Download Play Store Metadata selesai dengan sukses!"
        ]
        
        index = child.expect(success_phrases + ["❌ Terjadi kesalahan"], timeout=180)
        
        if index in [0, 1]:
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
