#!/usr/bin/env ruby

require 'dotenv/load'
ENV['FASTLANE_ENABLE_BETA_DELIVER_SYNC_SCREENSHOTS'] = '1'
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
bundle_id_arg = ARGV[2]

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
  choice_input = $stdin.gets
  choice = choice_input ? choice_input.chomp.strip : ""
  
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
    type_choice_input = $stdin.gets
    type_choice = type_choice_input ? type_choice_input.chomp.strip : ""
    
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
if bundle_id_arg && !bundle_id_arg.empty?
  bundle_id = bundle_id_arg
  puts "Menggunakan Bundle ID dari argumen: #{bundle_id}"
else
  print "Masukkan Bundle ID Aplikasi (Default: #{default_bundle_id}): "
  if !$stdin.tty?
    puts "\nNon-interactive shell dideteksi. Menggunakan default: #{default_bundle_id}"
    input_bundle_id = ""
  else
    input_bundle_id_raw = $stdin.gets
    input_bundle_id = input_bundle_id_raw ? input_bundle_id_raw.chomp.strip : ""
  end
  bundle_id = input_bundle_id.empty? ? default_bundle_id : input_bundle_id
end

# Normalize directory type name (HRM Apps -> Hrm Apps)
folder_type = app_type == "HRM Apps" ? "Hrm Apps" : app_type
template_root = File.join(project_root, "store_listings", folder_type)
template_ios_path = File.join(template_root, "ios")

# Validate template path exists
unless File.directory?(template_ios_path)
  puts "❌ Error: Template untuk tipe '#{app_type}' tidak ditemukan di 'store_listings/'."
  puts "   Jalur dicari: #{template_ios_path}"
  puts "   Silakan download template terlebih dahulu menggunakan menu Download App Store Metadata."
  exit 1
end

# Setup temporary directory inside project_root/tmp/project/<type>
tmp_dir = File.join(project_root, "tmp")
tmp_base = File.join(tmp_dir, run_id, "ios")
FileUtils.mkdir_p(tmp_base)
temp_metadata_dir = File.join(tmp_base, "metadata_#{Time.now.to_i}")
FileUtils.mkdir_p(temp_metadata_dir)

puts "📂 Menyalin template ke folder temporary: #{temp_metadata_dir}"
FileUtils.cp_r(File.join(template_ios_path, "."), temp_metadata_dir)

puts "\n============================================================"
puts "ℹ️ TARGET PUSH APP STORE METADATA & SCREENSHOT"
puts "============================================================"
puts "Project ID     : #{run_id}"
puts "Project Name   : #{app_data['Project']['Project Name']}"
puts "App Type       : #{app_type}"
puts "Bundle ID      : #{bundle_id}"
puts "Template Path  : #{template_ios_path}"
puts "Temp Path      : #{temp_metadata_dir}"
puts "============================================================\n"

# 4. Authenticate Setup
issuer_id = ENV['ASC_ISSUER_ID']
key_id = ENV['ASC_KEY_ID']
key_filepath = ENV['ASC_KEY_FILE']
apple_id = ENV['APPLE_ID_USERNAME']

if (issuer_id.nil? || issuer_id.empty?) && (apple_id.nil? || apple_id.empty?)
  puts "❌ Konfigurasi App Store Connect belum lengkap di .env."
  puts "   Anda harus mengisi ASC_ISSUER_ID (API Key) ATAU APPLE_ID_USERNAME (Apple ID biasa)."
  # Clean up temp folder before exit
  if temp_metadata_dir && File.directory?(temp_metadata_dir)
    FileUtils.rm_rf(temp_metadata_dir)
  end
  exit 1
end

using_api_key = !(issuer_id.nil? || issuer_id.empty?)

if using_api_key
  key_filepath = File.expand_path("../#{key_filepath}", script_dir)
  if !File.exist?(key_filepath)
    puts "❌ File API Key tidak ditemukan di: #{key_filepath}"
    # Clean up temp folder before exit
    if temp_metadata_dir && File.directory?(temp_metadata_dir)
      FileUtils.rm_rf(temp_metadata_dir)
    end
    exit 1
  end
end

# 5. Handle Icon download & prepare
custom_icon_url = app_data['Project']['Icon']
has_custom_icon = !custom_icon_url.nil? && !custom_icon_url.strip.empty?

if has_custom_icon
  puts "⬇️ Custom icon ditemukan: #{custom_icon_url}. Mengunduh dan mempersiapkan..."
  # Clean old icon files
  project_icon_path = File.join(project_root, "icon", "icon.png")
  FileUtils.rm_f(project_icon_path)
  FileUtils.rm_f(File.join(project_root, "icon", "icon_raw"))

  # Run prepare-icon.sh
  prepare_script = File.join(project_root, "scripts", "prepare-icon.sh")
  system("bash", prepare_script, custom_icon_url)
  
  if File.exist?(project_icon_path)
    puts "✅ Custom icon berhasil diunduh dan dipersiapkan."
  else
    puts "⚠️ Gagal mempersiapkan custom icon. Menggunakan icon bawaan template."
  end
else
  puts "ℹ️ Tidak ada custom icon untuk project ini. Menggunakan icon bawaan template."
end

# 6. Apply project custom values dynamically
puts "⚙️ Menyelaraskan informasi proyek (Name & Keywords) ke dalam temporary metadata..."
app_name = app_data['Project']['App Name'] || "My App"
if app_type == "Approval Apps"
  app_name = app_name.gsub(/\b(hris|hr|hrm)\b/i, '').strip
  app_name = app_name.gsub(/\s+/, ' ')
  app_name = "#{app_name} Approval".strip unless app_name.downcase.include?('approval')
end

# Force metadata and screenshots to English (en-US) only
puts "🌍 Memaksa bahasa metadata ke English (en-US)..."
id_metadata_path = File.join(temp_metadata_dir, "id")
en_metadata_path = File.join(temp_metadata_dir, "en-US")
FileUtils.mv(id_metadata_path, en_metadata_path) if File.directory?(id_metadata_path)

id_screenshots_path = File.join(temp_metadata_dir, "screenshots", "id")
en_screenshots_path = File.join(temp_metadata_dir, "screenshots", "en-US")
FileUtils.mv(id_screenshots_path, en_screenshots_path) if File.directory?(id_screenshots_path)

# Hapus locale lain selain en-US agar Fastlane hanya mengunggah en-US
Dir.glob(File.join(temp_metadata_dir, "*")).each do |dir|
  next unless File.directory?(dir)
  basename = File.basename(dir)
  unless ["en-US", "screenshots", "review_information"].include?(basename)
    FileUtils.rm_rf(dir)
  end
end

existing_locales = Dir.glob(File.join(temp_metadata_dir, "*")).select { |f| File.directory?(f) }.map { |f| File.basename(f) }
locales_to_update = existing_locales.reject { |name| ["screenshots", "review_information"].include?(name) }
locales_to_update = ["en-US", "id"] if locales_to_update.empty?

locales_to_update.each do |locale|
  locale_path = File.join(temp_metadata_dir, locale)
  FileUtils.mkdir_p(locale_path) unless File.directory?(locale_path)
  
  # 1. Update Name dengan App Name proyek
  name_file = File.join(locale_path, "name.txt")
  File.write(name_file, app_name)
  puts "   📝 Name [#{locale}] diselaraskan -> '#{app_name}'"

  # 2. Update Keywords dengan App Name proyek
  keywords_file = File.join(locale_path, "keywords.txt")
  File.write(keywords_file, app_name)
  puts "   📝 Keywords [#{locale}] diselaraskan -> '#{app_name}'"
end

# 7. Validation
puts "\n🔍 Melakukan validasi metadata sebelum mengunggah..."
validation_failed = false

locales_to_update.each do |locale|
  locale_path = File.join(temp_metadata_dir, locale)
  
  # Check Name (Max 30 chars)
  name_file = File.join(locale_path, "name.txt")
  if File.exist?(name_file)
    name = File.read(name_file).strip
    if name.length > 30
      puts "❌ [#{locale}] Name terlalu panjang: #{name.length} karakter (maksimal 30)"
      validation_failed = true
    end
  end
  
  # Check Subtitle (Max 30 chars)
  subtitle_file = File.join(locale_path, "subtitle.txt")
  if File.exist?(subtitle_file)
    subtitle = File.read(subtitle_file).strip
    if subtitle.length > 30
      puts "❌ [#{locale}] Subtitle terlalu panjang: #{subtitle.length} karakter (maksimal 30)"
      validation_failed = true
    end
  end
  
  # Check Description (Max 4000 chars)
  desc_file = File.join(locale_path, "description.txt")
  if File.exist?(desc_file)
    desc = File.read(desc_file).strip
    if desc.length > 4000
      puts "❌ [#{locale}] Description terlalu panjang: #{desc.length} karakter (maksimal 4000)"
      validation_failed = true
    end
  end

  # Check Keywords (Max 100 chars)
  kw_file = File.join(locale_path, "keywords.txt")
  if File.exist?(kw_file)
    kw = File.read(kw_file).strip
    if kw.length > 100
      puts "❌ [#{locale}] Keywords terlalu panjang: #{kw.length} karakter (maksimal 100)"
      validation_failed = true
    end
  end
end

if validation_failed
  puts "\n❌ Validasi metadata gagal. Silakan perbaiki isi file pada template App Store sebelum mencoba kembali."
  exit 1
else
  puts "✅ Validasi metadata sukses."
end

# 8. Interactive Confirmation & Execution
begin

  # 8. Build Deliver Options
  options = {
    app_identifier: bundle_id,
    metadata_path: temp_metadata_dir,
    screenshots_path: File.join(temp_metadata_dir, "screenshots"),
    skip_screenshots: false,
    overwrite_screenshots: true,
    sync_screenshots: true,
    skip_binary_upload: true,
    ignore_language_directory_validation: true,
    force: true
  }

  if has_custom_icon && File.exist?(project_icon_path)
    options[:app_icon] = project_icon_path
  end

  if using_api_key
    puts "🔑 Menggunakan API Key untuk otentikasi..."
    options[:api_key_path] = key_filepath
  else
    puts "🔑 Menggunakan Apple ID (#{apple_id}) untuk otentikasi..."
    options[:username] = apple_id
    options[:team_id] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
  end

  config = FastlaneCore::Configuration.create(Deliver::Options.available_options, options)
  
  puts "⏳ Menghubungkan ke App Store Connect dan mengunggah metadata & screenshots..."
  
  # Jalankan upload dalam thread agar responsive
  upload_thread = Thread.new do
    # Initialize runner first so it authenticates Spaceship automatically
    runner = Deliver::Runner.new(config)

    # 8a. Wipe all existing screenshots manually across all locales
    puts "🧹 Menghapus seluruh screenshot yang ada di App Store Connect..."
    app = Deliver.cache[:app]
    if app
      edit_version = app.get_edit_app_store_version
      if edit_version
        localizations = edit_version.get_app_store_version_localizations
        localizations.each do |loc|
          sets = loc.get_app_screenshot_sets
          sets.each do |set|
            puts "   🗑️  Menghapus screenshot lama dari locale: #{loc.locale}"
            set.delete!
          end
        end
      end
    end

    # 8b. Run Deliver to upload the new en-US metadata & screenshots
    runner.run
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
ensure
  if temp_metadata_dir && File.directory?(temp_metadata_dir)
    puts "\n🧹 Membersihkan folder temporary: #{temp_metadata_dir}"
    FileUtils.rm_rf(temp_metadata_dir)
  end
end
