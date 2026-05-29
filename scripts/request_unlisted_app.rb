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
bundle_id_arg = ARGV[2]

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
puts "🍎 REQUEST UNLISTED APP DISTRIBUTION"
puts "============================================================"

# Resolve Bundle ID and App Name
if bundle_id_arg && !bundle_id_arg.empty?
  bundle_id = bundle_id_arg
else
  bundle_id = app_data.dig('Bundle ID', app_type) || app_data.dig('Package ID', app_type)
  
  if bundle_id.nil? || bundle_id.empty?
    config_path = File.join(project_root, "config.json")
    if File.exist?(config_path)
      config = JSON.parse(File.read(config_path))
      prefix = config.dig('types', app_type, 'prefix') || "com.example"
      bundle_id = "#{prefix}.#{run_id}"
    else
      bundle_id = "com.example.#{run_id}"
    end
  end
end

app_name = app_data.dig('Project', 'App Name', app_type) || app_data.dig('Project', 'App Name') || "My App"
# Pastikan app_name bertipe String jika struktur JSON berubah
app_name = app_name.is_a?(Hash) ? app_name[app_type] : app_name

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
unlisted_request_url = "https://developer.apple.com/contact/request/unlisted-app/"

puts "\n✅ Berhasil mengambil data aplikasi dari App Store Connect!"
puts "Apple ID      : #{apple_id}"

puts "\n============================================================"
puts "📋 MENJALANKAN PLAYWRIGHT AUTOMATION"
puts "============================================================"
puts "Browser Chrome automation akan segera terbuka."
puts "-> Jika Anda belum login ke akun Apple Developer di profil Chrome ini, Anda akan diminta untuk login."
puts "-> Playwright akan otomatis mengisi form Unlisted App Request."
puts "-> Tunggu sampai skrip memberikan pesan PAUSE sebelum Anda menekan Submit."
puts "============================================================"

sleep(2)
# Execute playwright script passing App Name, Apple ID, and App Type
playwright_script = File.join(project_root, "automation", "request_unlisted_app.js")
system("node '#{playwright_script}' '#{app_name}' '#{apple_id}' '#{app_type}'")

puts "\n✨ Selesai!"
