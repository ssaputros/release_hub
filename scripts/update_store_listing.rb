#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'fileutils'

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
  puts "🗂️ PILIH PROJECT UNTUK UPDATE STORE LISTING"
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

# Resolve package name
config = File.exist?(config_path) ? JSON.parse(File.read(config_path)) : {}
prefix = "com.example"
if config['types'] && config['types'][app_type] && config['types'][app_type]['prefix']
  prefix = config['types'][app_type]['prefix']
end
package_name = "#{prefix}.#{run_id}"

# Normalize directory type name (HRM Apps -> Hrm Apps)
folder_type = app_type == "HRM Apps" ? "Hrm Apps" : app_type
metadata_root = File.join(project_root, "store_listings", folder_type, run_id, "metadata")

puts "\n============================================================"
puts "ℹ️ INFORMASI TARGET UPDATE STORE LISTING"
puts "============================================================"
puts "Project ID     : #{run_id}"
puts "Project Name   : #{app_data['Project']['Project Name']}"
puts "App Type       : #{app_type}"
puts "Package Name   : #{package_name}"
puts "Metadata Path  : #{metadata_root}"
puts "============================================================\n"

# 4. Check & Generate Auto-Template
metadata_android_path = File.join(metadata_root, "android")
locales = ["en-US", "id"] # Default locales

template_needed = false
unless File.directory?(metadata_android_path)
  puts "⚠️ Direktori metadata belum ada. Membuat folder struktur dan template otomatis..."
  template_needed = true
end

locales.each do |locale|
  locale_path = File.join(metadata_android_path, locale)
  unless File.directory?(locale_path)
    FileUtils.mkdir_p(locale_path)
    template_needed = true
  end
  
  # Text files template
  {
    "title.txt" => app_data['Project']['App Name'] || "My App",
    "short_description.txt" => "A wonderful application from #{app_data['Project']['Project Name']}.",
    "full_description.txt" => "This application is developed for #{app_data['Project']['Project Name']} to manage internal resources, administration, and services seamlessly."
  }.each do |file_name, content|
    file_path = File.join(locale_path, file_name)
    unless File.exist?(file_path)
      File.write(file_path, content)
      puts "📝 Terbuat: #{file_path}"
    end
  end
  
  # Image directories template
  images_path = File.join(locale_path, "images")
  FileUtils.mkdir_p(images_path) unless File.directory?(images_path)
  
  # Placeholder/Notes for images
  %w[phoneScreenshots sevenInchScreenshots tenInchScreenshots].each do |screenshot_dir|
    dir_path = File.join(images_path, screenshot_dir)
    FileUtils.mkdir_p(dir_path) unless File.directory?(dir_path)
  end
end

if template_needed
  puts "\n🎉 Folder struktur dan file template berhasil dibuat!"
  puts "👉 Silakan isi dan sesuaikan deskripsi aplikasi Anda di:"
  locales.each do |locale|
    puts "   - #{File.join(metadata_android_path, locale)}"
  end
  puts "👉 Dan taruh gambar pendukung (jika ada) di:"
  locales.each do |locale|
    puts "   - #{File.join(metadata_android_path, locale, 'images')}"
  end
  puts "\nSetelah selesai melengkapi metadata di atas, silakan jalankan skrip ini kembali untuk mengupload."
  exit 0
end

# 5. Validation
puts "🔍 Melakukan validasi metadata sebelum mengunggah..."
validation_failed = false

locales.each do |locale|
  locale_path = File.join(metadata_android_path, locale)
  
  # Check Title (Max 50 chars)
  title_file = File.join(locale_path, "title.txt")
  if File.exist?(title_file)
    title = File.read(title_file).strip
    if title.length > 50
      puts "❌ [#{locale}] Title terlalu panjang: #{title.length} karakter (maksimal 50)"
      validation_failed = true
    end
  end
  
  # Check Short Description (Max 80 chars)
  short_file = File.join(locale_path, "short_description.txt")
  if File.exist?(short_file)
    short = File.read(short_file).strip
    if short.length > 80
      puts "❌ [#{locale}] Short Description terlalu panjang: #{short.length} karakter (maksimal 80)"
      validation_failed = true
    end
  end
  
  # Check Full Description (Max 4000 chars)
  full_file = File.join(locale_path, "full_description.txt")
  if File.exist?(full_file)
    full = File.read(full_file).strip
    if full.length > 4000
      puts "❌ [#{locale}] Full Description terlalu panjang: #{full.length} karakter (maksimal 4000)"
      validation_failed = true
    end
  end
end

if validation_failed
  puts "\n❌ Validasi gagal. Silakan perbaiki metadata Anda terlebih dahulu."
  exit 1
end
puts "✅ Validasi metadata berhasil!"

# 6. Interactive Confirmation
print "\nApakah Anda yakin ingin mengunggah metadata ini ke Google Play Console? (y/n): "
confirm = $stdin.gets.chomp.strip.downcase
unless confirm == 'y' || confirm == 'yes'
  puts "Dibatalkan."
  exit 0
end

# 7. Execute Fastlane Supply Uploader
puts "\n🚀 Memulai proses pengunggahan ke Google Play Store via Fastlane Supply..."

begin
  require 'supply'
  
  # Supply requires metadata_path to point to the directory containing locale folders directly, 
  # which in our case is 'store_listings/<App Type>/<Branch>/metadata/android'
  options = {
    package_name: package_name,
    json_key: json_key,
    metadata_path: metadata_android_path,
    skip_upload_apk: true,
    skip_upload_aab: true,
    skip_upload_changelogs: true,
    skip_upload_images: false,      # Allow upload if present
    skip_upload_screenshots: false   # Allow upload if present
  }
  
  config = FastlaneCore::Configuration.create(Supply::Options.available_options, options)
  
  upload_thread = Thread.new do
    Supply::Uploader.new.perform_upload(config)
  end
  
  # Spinner feedback
  spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
  i = 0
  start_time = Time.now
  while upload_thread.alive?
    elapsed = (Time.now - start_time).to_i
    mins = elapsed / 60
    secs = elapsed % 60
    print "\r⏳ #{spinner[i % spinner.length]} Mengunggah store listing... (Waktu berlalu: #{mins}m #{secs}s)   "
    i += 1
    sleep 0.2
  end
  
  upload_thread.join
  puts "\n\n✅ Upload Store Listing Play Store selesai dengan sukses!"
rescue => ex
  puts "\n❌ Terjadi kesalahan saat mengunggah ke Play Store:"
  puts ex.message
  exit 1
end
