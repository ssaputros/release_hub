#!/usr/bin/env python3

import os
import sys
import json
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Tentukan scope akses ke Google Drive
SCOPES = ['https://www.googleapis.com/auth/drive', 'https://www.googleapis.com/auth/drive.file']

def get_or_create_subfolder(service, parent_id, folder_name):
    query = f"name='{folder_name}' and '{parent_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
    results = service.files().list(q=query, spaces='drive', fields='files(id, name)').execute()
    items = results.get('files', [])
    
    if not items:
        print(f"📁 Membuat folder baru di Drive: {folder_name}")
        folder_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [parent_id]
        }
        folder = service.files().create(body=folder_metadata, fields='id').execute()
        return folder.get('id')
    else:
        return items[0].get('id')

def upload_file(file_path, parent_folder_id, credentials_path, project_name, app_name):
    if not os.path.exists(file_path):
        print(f"❌ File tidak ditemukan: {file_path}")
        sys.exit(1)
        
    creds = None
    is_service_account = False
    
    try:
        if os.path.exists(credentials_path):
            with open(credentials_path, 'r') as f:
                creds_data = json.load(f)
                
            if 'access_token' in creds_data:
                client_id = creds_data.get('client_id', '622821984122-lm5441upc92rdusqah4tc6njh4tphjmm.apps.googleusercontent.com')
                client_secret = creds_data.get('client_secret', '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')

                creds = Credentials(
                    token=creds_data.get('access_token'),
                    refresh_token=creds_data.get('refresh_token'),
                    token_uri='https://oauth2.googleapis.com/token',
                    client_id=client_id,
                    client_secret=client_secret,
                    scopes=SCOPES
                )
            elif creds_data.get('type') == 'service_account':
                creds = service_account.Credentials.from_service_account_file(
                    credentials_path, scopes=SCOPES)
                is_service_account = True
    except Exception:
        creds = None

    if not is_service_account:
        from google.auth.transport.requests import Request
        from google.auth.exceptions import RefreshError
        
        # Coba refresh jika token ada tapi sudah expired
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except RefreshError:
                creds = None
        elif creds and not creds.valid:
            try:
                creds.refresh(Request())
            except Exception:
                creds = None
                
        # Jika belum ada creds (file tidak ada) atau token gagal direfresh (invalid_grant)
        if not creds or not creds.valid:
            print("⚠️ File kredensial kosong, tidak valid, atau token telah expired.")
            print("⏳ Memulai proses otentikasi browser otomatis untuk membuat token baru...")
            try:
                from google_auth_oauthlib.flow import InstalledAppFlow
                client_config = {
                    "installed": {
                        "client_id": "622821984122-lm5441upc92rdusqah4tc6njh4tphjmm.apps.googleusercontent.com",
                        "project_id": "hmx-upload",
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                        "client_secret": "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",
                        "redirect_uris": ["http://localhost"]
                    }
                }
                flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
                creds = flow.run_local_server(port=0)
                
                token_data = {
                    'access_token': creds.token,
                    'refresh_token': creds.refresh_token,
                    'token_uri': creds.token_uri,
                    'client_id': creds.client_id,
                    'client_secret': creds.client_secret,
                    'scopes': creds.scopes
                }
                os.makedirs(os.path.dirname(credentials_path), exist_ok=True)
                with open(credentials_path, 'w') as f:
                    json.dump(token_data, f, indent=4)
                print("✅ Token OAuth baru berhasil dibuat dan disimpan.")
            except Exception as e:
                print(f"❌ Gagal melakukan otentikasi otomatis: {e}")
                sys.exit(1)

    try:
        # Bangun service Google Drive
        service = build('drive', 'v3', credentials=creds)
        
        # Dapatkan ID subfolder tujuan
        target_folder_name = f"{project_name} ( {app_name} )" if app_name else project_name
        target_folder_id = get_or_create_subfolder(service, parent_folder_id, target_folder_name)

        file_name = os.path.basename(file_path)
        print(f"⏳ Mengunggah {file_name} ke dalam folder '{target_folder_name}'...")

        # Metadata file, tentukan nama file dan folder tujuan
        file_metadata = {
            'name': file_name,
            'parents': [target_folder_id]
        }

        # MediaFileUpload otomatis mengenali tipe MIME
        media = MediaFileUpload(file_path, resumable=True, chunksize=1024*1024)

        # Proses unggah
        request = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, webViewLink'
        )
        
        response = None
        while response is None:
            status, response = request.next_chunk()
            if status:
                print(f"⏳ Progress: {int(status.progress() * 100)}%", end='\r', flush=True)

        file = response
        print(f"\n✅ Berhasil mengunggah: {file_name}")
        print(f"🔗 Link: {file.get('webViewLink')}")
        
    except Exception as e:
        print(f"❌ Terjadi kesalahan saat mengunggah: {e}")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 6:
        print("Usage: python3 upload_to_gdrive.py <file_path> <folder_id> <credentials_path> <project_name> <app_name>")
        sys.exit(1)

    file_to_upload = sys.argv[1]
    gdrive_folder_id = sys.argv[2]
    service_account_file = sys.argv[3]
    project_name = sys.argv[4]
    app_name = sys.argv[5]

    upload_file(file_to_upload, gdrive_folder_id, service_account_file, project_name, app_name)
