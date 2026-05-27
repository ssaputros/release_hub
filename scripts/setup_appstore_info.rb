#!/usr/bin/env ruby

require 'json'
require 'fileutils'

begin
  require 'spaceship'
rescue LoadError
  puts "❌ Error: fastlane / spaceship belum terinstall."
  puts "Jalankan: gem install fastlane"
  exit 1
end

# 1. Path definitions
script_dir = __dir__
project_root = File.expand_path("..", script_dir)
projects_path = File.join(project_root, "projects.json")

# 2. Check dependencies
unless File.exist?(projects_path)
  puts "❌ Error: projects.json tidak ditemukan."
  exit 1
end

projects = JSON.parse(File.read(projects_path))

# 3. Argument Parsing
run_id = ARGV[0]
app_type = ARGV[1]

if run_id.nil? || run_id.empty?
  puts "❌ Error: Parameter Project ID kosong."
  exit 1
end

app_data = projects[run_id]
unless app_data
  puts "❌ Error: Project dengan ID '#{run_id}' tidak ditemukan di projects.json."
  exit 1
end

project_types = (app_data['Project']['Type'] || "").split(",").map(&:strip).reject(&:empty?)

if app_type.nil? || app_type.empty?
  if project_types.length > 1
    puts "❌ Error: Parameter App Type kosong."
    exit 1
  else
    app_type = project_types.first
  end
end

puts "\n============================================================"
puts "🍎 SETUP APP STORE INFORMATION"
puts "============================================================"

# Resolve Bundle ID and App Name from projects.json
bundle_id = app_data['Bundle ID'][app_type]
app_name = app_data['Project']['App Name'][app_type] || "My App"

puts "Project       : #{app_data['Project']['Project Name']}"
puts "App Type      : #{app_type}"
puts "Bundle ID     : #{bundle_id}"
puts "App Name      : #{app_name}"
puts "------------------------------------------------------------"

puts "⏳ Menghubungkan ke App Store Connect..."
begin
  Spaceship::ConnectAPI.login
rescue => e
  puts "❌ Gagal login ke App Store Connect: #{e.message}"
  exit 1
end

app = Spaceship::ConnectAPI::App.find(bundle_id)

unless app
  puts "❌ Aplikasi dengan Bundle ID '#{bundle_id}' tidak ditemukan di App Store Connect."
  puts "⚠️ Pastikan Anda sudah menjalankan opsi 'Push App Store Metadata' setidaknya sekali untuk membuat aplikasi."
  exit 1
end

apple_id = app.id
app_store_connect_url = "https://appstoreconnect.apple.com/apps/#{apple_id}/distribution/info"

puts "\n✅ Berhasil mengambil data aplikasi dari App Store Connect!"
puts "Apple ID      : #{apple_id}"

puts "\n============================================================"
puts "📋 MENJALANKAN PLAYWRIGHT INSPECTOR"
puts "============================================================"
puts "Browser Chrome automation akan segera terbuka dengan sesi Anda."
puts "-> Tunggu Playwright Inspector muncul."
puts "-> Klik RECORD dan mulailah melengkapi data App Store Info Anda."
puts "-> Setelah selesai merekam dan mengisi form, silakan tutup browser."
puts "============================================================"

sleep(2)
playwright_script = File.join(project_root, "automation", "setup_appstore_info.js")
system("node '#{playwright_script}' '#{apple_id}' '#{app_name}'")

puts "\n✨ Selesai!"
