#!/usr/bin/env python3

import json
import os
import sys
from google_auth_oauthlib.flow import InstalledAppFlow

# Scope Google Drive untuk upload file
SCOPES = ['https://www.googleapis.com/auth/drive', 'https://www.googleapis.com/auth/drive.file']

# Client ID bawaan (Anda juga bisa menggunakan Client ID Anda sendiri dari Google Cloud)
DEFAULT_CLIENT_ID = '622821984122-lm5441upc92rdusqah4tc6njh4tphjmm.apps.googleusercontent.com'
DEFAULT_CLIENT_SECRET = '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'

def generate_token():
    print("============================================================")
    print("🔐 GENERATE OAUTH 2.0 TOKEN UNTUK GOOGLE DRIVE")
    print("============================================================\n")
    print("Membuka browser untuk otentikasi akun Google Anda...")
    
    # Konfigurasi OAuth Client
    client_config = {
        "installed": {
            "client_id": DEFAULT_CLIENT_ID,
            "project_id": "hmx-upload",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_secret": DEFAULT_CLIENT_SECRET,
            "redirect_uris": ["http://localhost"]
        }
    }

    try:
        # Jalankan OAuth flow (akan membuka browser secara otomatis)
        flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
        creds = flow.run_local_server(port=0)
        
        # Susun data token
        token_data = {
            'access_token': creds.token,
            'refresh_token': creds.refresh_token,
            'token_uri': creds.token_uri,
            'client_id': creds.client_id,
            'client_secret': creds.client_secret,
            'scopes': creds.scopes
        }

        # Pastikan folder credentials ada
        script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        creds_dir = os.path.join(script_dir, 'credentials')
        os.makedirs(creds_dir, exist_ok=True)
        
        token_path = os.path.join(creds_dir, 'gdrive_service_account.json')
        
        # Tulis token ke file JSON
        with open(token_path, 'w') as f:
            json.dump(token_data, f, indent=4)
            
        print(f"\n✅ BERHASIL! Token baru telah disimpan di: {token_path}")
        print("Silakan jalankan ulang perintah release -u Anda.\n")
        
    except Exception as e:
        print(f"\n❌ Gagal membuat token: {e}")
        sys.exit(1)

if __name__ == '__main__':
    generate_token()
