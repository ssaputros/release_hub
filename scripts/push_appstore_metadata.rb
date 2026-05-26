#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'fileutils'
require 'fastlane'
require 'deliver'
require 'deliver/options'
require 'fastlane_core'

# 1. Path definitions
script_dir = __dir__
project_root = File.expand_path("..", script_dir)
projects_path = File.join(project_root, "projects.json")
config_path = File.join(project_root, "config.json")

# 2. Check dependencies
unless File.exist?(projects_path)
  puts "❌ Error: projects.json tidak ditemukan."
  exit 1
end

projects = JSON.parse(File.read(projects_path))

# 3. Handle arguments or interactive selection
run_id = ARGV[0]
app_type = ARGV[1]

if run_id.nil? || run_id.empty?
  puts "============================================================"
  puts "🍎 PILIH PROJECT UNTUK PUSH APP STORE METADATA"
  puts "============================================================"
  
  available_projects = projects.keys
  available_projects.each_with_index do |key, idx|
    puts "#{idx + 1}) #{key} (#{projects[key]['Project']['Project Name']})"
  end
  puts "0) Keluar"
  puts "------------------------------------------------------------"
  print "Pilihan Anda: "
  choice = $stdin.gets.chomp.strip
  
  if choice == '0' || choice.empty?
    puts "Batal."
    exit 0
  end
  
  choice_idx = choice.to_i - 1
  if choice_idx >= 0 && choice_idx < available_projects.length
    run_id = available_projects[choice_idx]
  else
    puts "❌ Pilihan tidak valid."
    exit 1
  end
end

app_data = projects[run_id]
unless app_data
  puts "❌ Error: Project dengan ID '#{run_id}' tidak ditemukan di projects.json."
  exit 1
end

# Check types
project_types = (app_data['Project']['Type'] || "").split(",").map(&:strip).reject(&:empty?)
if project_types.empty?
  puts "❌ Error: Project ini tidak memiliki tipe yang didefinisikan."
  exit 1
end

if app_type.nil? || app_type.empty?
  if project_types.length > 1
    puts "\n============================================================"
    puts "🗂️ PILIH TIPE APLIKASI UNTUK #{app_data['Project']['Project Name']}"
    puts "============================================================"
    project_types.each_with_index do |t, idx|
      puts "#{idx + 1}) #{t}"
    end
    puts "0) Keluar"
    puts "------------------------------------------------------------"
    print "Pilihan Anda: "
    type_choice = $stdin.gets.chomp.strip
    
    if type_choice == '0' || type_choice.empty?
      puts "Batal."
      exit 0
    end
    
    type_idx = type_choice.to_i - 1
    if type_idx >= 0 && type_idx < project_types.length
      app_type = project_types[type_idx]
    else
      puts "❌ Pilihan tidak valid."
      exit 1
    end
  else
    app_type = project_types.first
  end
end

# Resolve package name (used as default Bundle ID)
config = File.exist?(config_path) ? JSON.parse(File.read(config_path)) : {}
prefix = "com.example"
if config['types'] && config['types'][app_type] && config['types'][app_type]['prefix']
  prefix = config['types'][app_type]['prefix']
end
default_bundle_id = "#{prefix}.#{run_id}"

# Input Bundle ID
puts "\n============================================================"
puts "🔑 INPUT BUNDLE ID"
puts "============================================================"
print "Masukkan Bundle ID Aplikasi (Default: #{default_bundle_id}): "
input_bundle_id = $stdin.gets.chomp.strip
bundle_id = input_bundle_id.empty? ? default_bundle_id : input_bundle_id

# Normalize directory type name (HRM Apps -> Hrm Apps)
folder_type = app_type == "HRM Apps" ? "Hrm Apps" : app_type
metadata_root = File.join(project_root, "store_listings", folder_type, run_id, "metadata")
metadata_ios_path = File.join(metadata_root, "ios")

# Validate metadata path exists
unless File.directory?(metadata_ios_path)
  puts "❌ Error: Direktori metadata iOS tidak ditemukan di '#{metadata_ios_path}'"
  puts "   Silakan download metadata terlebih dahulu menggunakan opsi Download App Store Metadata."
  exit 1
end

puts "\n============================================================"
puts "ℹ️ TARGET PUSH APP STORE METADATA"
puts "============================================================"
puts "Project ID     : #{run_id}"
puts "Project Name   : #{app_data['Project']['Project Name']}"
puts "App Type       : #{app_type}"
puts "Bundle ID      : #{bundle_id}"
puts "Metadata Path  : #{metadata_ios_path}"
puts "============================================================\n"

# 4. Authenticate Setup
issuer_id = ENV['ASC_ISSUER_ID']
key_id = ENV['ASC_KEY_ID']
key_filepath = ENV['ASC_KEY_FILE']
apple_id = ENV['APPLE_ID_USERNAME']

if (issuer_id.nil? || issuer_id.empty?) && (apple_id.nil? || apple_id.empty?)
  puts "❌ Konfigurasi App Store Connect belum lengkap di .env."
  puts "   Anda harus mengisi ASC_ISSUER_ID (API Key) ATAU APPLE_ID_USERNAME (Apple ID biasa)."
  exit 1
end

using_api_key = !(issuer_id.nil? || issuer_id.empty?)

if using_api_key
  key_filepath = File.expand_path("../#{key_filepath}", script_dir)
  if !File.exist?(key_filepath)
    puts "❌ File API Key tidak ditemukan di: #{key_filepath}"
    exit 1
  end
end

# 5. Interactive Confirmation
print "\nApakah Anda yakin ingin mengunggah metadata ini ke App Store Connect? (y/n): "
confirm = $stdin.gets.chomp.strip.downcase
unless confirm == 'y' || confirm == 'yes'
  puts "Dibatalkan."
  exit 0
end

# 6. Build Deliver Options
options = {
  app_identifier: bundle_id,
  metadata_path: metadata_ios_path,
  skip_screenshots: true,
  skip_binary_upload: true,
  force: true
}

if using_api_key
  puts "🔑 Menggunakan API Key untuk otentikasi..."
  options[:api_key_path] = key_filepath
else
  puts "🔑 Menggunakan Apple ID (#{apple_id}) untuk otentikasi..."
  options[:username] = apple_id
  options[:team_id] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
end

begin
  config = FastlaneCore::Configuration.create(Deliver::Options.available_options, options)
  
  puts "⏳ Menghubungkan ke App Store Connect dan mengunggah metadata..."
  
  # Jalankan upload dalam thread agar responsive
  upload_thread = Thread.new do
    Deliver::Runner.new(config).run
  end
  
  spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
  i = 0
  start_time = Time.now
  while upload_thread.alive?
    elapsed = (Time.now - start_time).to_i
    mins = elapsed / 60
    secs = elapsed % 60
    print "\r⏳ #{spinner[i % spinner.length]} Mengunggah metadata... (Waktu berlalu: #{mins}m #{secs}s)   "
    i += 1
    sleep 0.2
  end
  
  upload_thread.join
  puts "\n\n✅ Upload App Store Metadata selesai dengan sukses!"
rescue => ex
  puts "\n❌ Terjadi kesalahan saat mengunggah metadata App Store:"
  puts ex.message
  exit 1
end
