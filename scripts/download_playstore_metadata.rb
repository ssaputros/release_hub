#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'fileutils'
require 'fastlane'
require 'supply'
require 'supply/setup'
require 'fastlane_core'

# 1. Path definitions
script_dir = __dir__
project_root = File.expand_path("..", script_dir)
projects_path = File.join(project_root, "projects.json")
config_path = File.join(project_root, "config.json")
credentials_dir = File.join(project_root, "credentials")
json_key = ENV['PLAYSTORE_JSON_KEY'] || File.join(credentials_dir, "playstore_service_account.json")

# 2. Check dependencies
unless File.exist?(projects_path)
  puts "❌ Error: projects.json tidak ditemukan."
  exit 1
end

unless File.exist?(json_key)
  puts "❌ Error: File kredensial JSON Play Store tidak ditemukan di '#{json_key}'"
  puts "Silakan ikuti instruksi di docs/PlayStoreSetup.md untuk menyiapkannya."
  exit 1
end

projects = JSON.parse(File.read(projects_path))

# 3. Handle arguments or interactive selection
run_id = ARGV[0]
app_type = ARGV[1]

if run_id.nil? || run_id.empty?
  puts "============================================================"
  puts "🤖 PILIH PROJECT UNTUK DOWNLOAD PLAY STORE METADATA"
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

# Resolve package name (used as default Package Name)
config = File.exist?(config_path) ? JSON.parse(File.read(config_path)) : {}
prefix = "com.example"
if config['types'] && config['types'][app_type] && config['types'][app_type]['prefix']
  prefix = config['types'][app_type]['prefix']
end
default_package_name = "#{prefix}.#{run_id}"

# Input Package Name
puts "\n============================================================"
puts "🔑 INPUT PACKAGE NAME"
puts "============================================================"
print "Masukkan Package Name Aplikasi (Default: #{default_package_name}): "
input_package_name = $stdin.gets.chomp.strip
package_name = input_package_name.empty? ? default_package_name : input_package_name

# Normalize directory type name (HRM Apps -> Hrm Apps)
folder_type = app_type == "HRM Apps" ? "Hrm Apps" : app_type

# Ask user for custom folder name
puts "\n============================================================"
puts "📂 TENTUKAN FOLDER TUJUAN"
puts "============================================================"
print "Masukkan nama folder penyimpanan (Default: #{folder_type}): "
input_folder = $stdin.gets.chomp.strip
target_folder = input_folder.empty? ? folder_type : input_folder

metadata_root = File.join(project_root, "store_listings", target_folder)
metadata_android_path = File.join(metadata_root, "android")

# Clean existing directory to prevent Supply setup from skipping download
if File.exist?(metadata_android_path)
  puts "🧹 Membersihkan direktori metadata lokal lama di #{metadata_android_path}..."
  FileUtils.rm_rf(metadata_android_path)
end

puts "\n============================================================"
puts "ℹ️ TARGET DOWNLOAD PLAY STORE METADATA"
puts "============================================================"
puts "Project ID     : #{run_id}"
puts "Project Name   : #{app_data['Project']['Project Name']}"
puts "App Type       : #{app_type}"
puts "Package Name   : #{package_name}"
puts "Metadata Path  : #{metadata_android_path}"
puts "============================================================\n"

# 4. Build Supply Options
options = {
  package_name: package_name,
  json_key: json_key,
  metadata_path: metadata_android_path
}

begin
  Supply.config = FastlaneCore::Configuration.create(Supply::Options.available_options, options)
  
  puts "⏳ Menghubungkan ke Google Play Console dan mendownload metadata serta screenshots..."
  
  # Jalankan download dalam thread agar responsive
  download_thread = Thread.new do
    Supply::Setup.new.perform_download
  end
  
  spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
  i = 0
  start_time = Time.now
  while download_thread.alive?
    elapsed = (Time.now - start_time).to_i
    mins = elapsed / 60
    secs = elapsed % 60
    print "\r⏳ #{spinner[i % spinner.length]} Mendownload metadata... (Waktu berlalu: #{mins}m #{secs}s)   "
    i += 1
    sleep 0.2
  end
  
  download_thread.join
  puts "\n\n✅ Download Play Store Metadata selesai dengan sukses!"
  puts "📁 Hasil disimpan di: #{metadata_android_path}"
rescue => ex
  puts "\n❌ Terjadi kesalahan saat mendownload metadata Play Store:"
  puts ex.message
  exit 1
end
