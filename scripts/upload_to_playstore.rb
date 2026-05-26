#!/usr/bin/env ruby

require 'dotenv/load'
require 'fastlane'
require 'pilot'

if ARGV.length < 2
  puts "Usage: ruby upload_to_playstore.rb <path_to_aab> <package_name> [track]"
  puts "Track default adalah 'internal'"
  exit 1
end

aab_path = ARGV[0]
package_name = ARGV[1]
track = ARGV[2] || "internal"

if !File.exist?(aab_path)
  puts "❌ Error: File AAB tidak ditemukan di '#{aab_path}'"
  exit 1
end

script_dir = File.expand_path("..", __dir__)
json_key = ENV['PLAYSTORE_JSON_KEY'] || File.join(script_dir, "credentials", "playstore_service_account.json")

if !File.exist?(json_key)
  puts "❌ Error: File kredensial JSON Play Store tidak ditemukan di '#{json_key}'"
  puts "Silakan ikuti instruksi di docs/PlayStoreSetup.md untuk menyiapkannya."
  exit 1
end

puts "🚀 Mengunggah #{File.basename(aab_path)} ke Google Play Store (Track: #{track})..."

begin
  require 'supply'
  
  options = {
    package_name: package_name,
    track: track,
    aab: aab_path,
    json_key: json_key,
    skip_upload_metadata: true,
    skip_upload_images: true,
    skip_upload_screenshots: true
  }

  Supply.config = FastlaneCore::Configuration.create(Supply::Options.available_options, options)
  
  # Jalankan upload via thread agar kita bisa menampilkan indikator progress (menghindari kesan terminal hang)
  upload_thread = Thread.new do
    Supply::Uploader.new.perform_upload
  end
  
  sleep 2
  puts ""
  
  spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
  i = 0
  start_time = Time.now
  while upload_thread.alive?
    elapsed = (Time.now - start_time).to_i
    mins = elapsed / 60
    secs = elapsed % 60
    print "\r⏳ #{spinner[i % spinner.length]} Mengunggah AAB ke Play Console... (Waktu berlalu: #{mins}m #{secs}s)   "
    i += 1
    sleep 0.2
  end
  
  upload_thread.join
  puts "\n✅ Upload Play Store selesai!"
rescue => ex
  puts "\n❌ Terjadi kesalahan saat mengunggah ke Play Store:"
  puts ex.message
  exit 1
end
