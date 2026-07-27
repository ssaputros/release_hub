#!/usr/bin/env ruby

require 'fastlane'
require 'spaceship'
require 'dotenv'
require 'json'
require_relative 'app_store_connect_auth_helper'

# Muat file .env dari root directory
Dotenv.load(File.expand_path('../../.env', __FILE__))

ipa_path = ARGV[0]
app_identifier = ARGV[1]
app_name = ARGV[2]
app_type = ARGV[3]

if ipa_path.nil? || app_identifier.nil?
  puts "Usage: ruby upload_to_testflight.rb <ipa_path> <app_identifier> [app_name] [app_type]"
  exit 1
end

# Membaca config.json untuk info beta review
config_file = File.expand_path('../../config.json', __FILE__)
review_info = {}
if File.exist?(config_file) && !app_type.nil? && !app_type.empty?
  begin
    config_data = JSON.parse(File.read(config_file))
    review_info = config_data.dig('types', app_type, 'beta_app_review_info') || {}
  rescue => e
    puts "⚠️ Gagal membaca config.json: #{e.message}"
  end
end

issuer_id = ENV['ASC_ISSUER_ID']
apple_id = ENV['APPLE_ID_USERNAME']
project_root = File.expand_path('..', __dir__)

if (issuer_id.nil? || issuer_id.empty?) && (apple_id.nil? || apple_id.empty?)
  puts "❌ Konfigurasi App Store Connect belum lengkap di .env."
  puts "   Anda harus mengisi ASC_ISSUER_ID (API Key) ATAU APPLE_ID_USERNAME (Apple ID biasa)."
  exit 1
end

using_api_key = !(issuer_id.nil? || issuer_id.empty?)
key_filepath = AppStoreConnectAuthHelper.resolve_api_key_path(project_root: project_root) if using_api_key

begin
  AppStoreConnectAuthHelper.ensure_authenticated!(
    context: "Upload App Store #{app_name || app_identifier}",
    project_root: project_root
  )
  ENV.delete('FASTLANE_TEAM_ID') unless using_api_key # Hindari Spaceship Connect API salah baca team saat upload App Store.
  
  # Cari App
  app = Spaceship::ConnectAPI::App.find(app_identifier)
  if app.nil?
    puts "❌ App dengan bundle ID #{app_identifier} tidak ditemukan di App Store Connect."
    puts "⚠️ Pastikan Anda sudah membuat App ini (misalnya dengan init_appstore.sh) sebelum mengunggah build."
    exit 1
  end

  puts "🚀 Mengunggah #{File.basename(ipa_path)} ke TestFlight..."
  
  require 'pilot'
  
  # Konfigurasi Upload Pilot
  options = {
    app_identifier: app_identifier,
    ipa: ipa_path,
    skip_waiting_for_build_processing: true # Skrip tidak akan terblokir menunggu Apple
  }
  
  if using_api_key
    options[:api_key_path] = key_filepath
  else
    options[:username] = apple_id
    options[:team_id] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
    options[:itc_provider] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
    options[:dev_portal_team_id] = ENV['TEAM_ID'] if ENV['TEAM_ID']
    
    puts "\n⚠️ CATATAN UNTUK UPLOAD DENGAN APPLE ID:"
    puts "Jika upload gagal di tengah jalan dengan error 'Application Specific Password',"
    puts "pastikan Anda telah men-generate App-Specific Password di appleid.apple.com"
    puts "dan menambahkannya di .env Anda sebagai:"
    puts "FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=\"password-anda\"\n\n"
  end

  config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
  
  AppStoreConnectAuthHelper.with_auth_retry(
    context: "Upload IPA App Store #{app_name || app_identifier}",
    project_root: project_root
  ) do
    if ENV['SKIP_UPLOAD'] == 'true'
      puts "⏭️ Melewati proses upload IPA karena SKIP_UPLOAD=true..."
    else
      AppStoreConnectAuthHelper.run_with_spinner('Mengunggah IPA ke Apple Server') do
        Pilot::BuildManager.new.upload(config)
      end
      puts "✅ Upload IPA selesai!"
    end
  end
  
  puts "\n🎉 Build berhasil diunggah ke App Store Connect!"
  puts "Build sekarang dapat digunakan untuk TestFlight (Internal/External) atau disubmit untuk App Store Review."
  
rescue => e
  puts "❌ Terjadi kesalahan: #{e.message}"
  exit 1
end
