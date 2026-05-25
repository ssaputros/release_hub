import json
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

with open('credentials/gdrive_service_account.json', 'r') as f:
    creds_data = json.load(f)

client_id = '622821984122-lm5441upc92rdusqah4tc6njh4tphjmm.apps.googleusercontent.com'
client_secret = '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'

creds = Credentials(
    token=creds_data.get('access_token'),
    refresh_token=creds_data.get('refresh_token'),
    token_uri='https://oauth2.googleapis.com/token',
    client_id=client_id,
    client_secret=client_secret
)

try:
    creds.refresh(Request())
    print("Token refreshed successfully")
except Exception as e:
    print(f"Error: {e}")
