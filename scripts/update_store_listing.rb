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
  puts "❌ Error: Project dengan ID '#{run_id}' not found in projects.json."
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

# Resolve package name
config = File.exist?(config_path) ? JSON.parse(File.read(config_path)) : {}
prefix = "com.example"
if config['types'] && config['types'][app_type] && config['types'][app_type]['prefix']
  prefix = config['types'][app_type]['prefix']
end
package_name = "#{prefix}.#{run_id}"

# Normalize directory type name (HRM Apps -> Hrm Apps)
folder_type = app_type == "HRM Apps" ? "Hrm Apps" : app_type
template_root = File.join(project_root, "store_listings", folder_type)
template_android_path = File.join(template_root, "android")

# Validate template path exists
unless File.directory?(template_android_path)
  puts "❌ Error: Template untuk tipe '#{app_type}' tidak ditemukan di 'store_listings/'."
  puts "   Jalur dicari: #{template_android_path}"
  puts "   Silakan download template terlebih dahulu menggunakan menu Download Play Store Metadata."
  exit 1
end

# Setup temporary directory inside project_root/tmp/project/<type>
tmp_dir = File.join(project_root, "tmp")
tmp_base = File.join(tmp_dir, run_id, "android")
FileUtils.mkdir_p(tmp_base)
temp_metadata_dir = File.join(tmp_base, "metadata_#{Time.now.to_i}")
FileUtils.mkdir_p(temp_metadata_dir)

puts "📂 Menyalin template ke folder temporary: #{temp_metadata_dir}"
FileUtils.cp_r(File.join(template_android_path, "."), temp_metadata_dir)

puts "\n============================================================"
puts "ℹ️ INFORMASI TARGET UPDATE STORE LISTING"
puts "============================================================"
puts "Project ID     : #{run_id}"
puts "Project Name   : #{app_data['Project']['Project Name']}"
puts "App Type       : #{app_type}"
puts "Package Name   : #{package_name}"
puts "Template Path  : #{template_android_path}"
puts "Temp Path      : #{temp_metadata_dir}"
puts "============================================================\n"

# 4. Handle Icon download & prepare
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
  system("bash", prepare_script, custom_icon_url, "512")
  
  if File.exist?(project_icon_path)
    puts "✅ Custom icon berhasil diunduh dan dipersiapkan."
  else
    puts "⚠️ Gagal mempersiapkan custom icon. Menggunakan icon bawaan template."
    has_custom_icon = false
  end
else
  puts "ℹ️ Tidak ada custom icon untuk project ini. Menggunakan icon bawaan template."
end

# 5. Detect locales in the template
existing_locales = Dir.glob(File.join(temp_metadata_dir, "*")).select { |f| File.directory?(f) }.map { |f| File.basename(f) }
locales = existing_locales.empty? ? ["en-US", "id"] : existing_locales

# 6. Apply project custom values dynamically
puts "⚙️ Menyelaraskan informasi proyek (Title & Icon) ke dalam temporary metadata..."
app_name = app_data['Project']['App Name'] || "My App"
if app_type == "Approval Apps"
  app_name = app_name.gsub(/\b(hris|hr|hrm)\b/i, '').strip
  app_name = app_name.gsub(/\s+/, ' ')
  app_name = "#{app_name} Approval".strip unless app_name.downcase.include?('approval')
end
project_icon_path = File.join(project_root, "icon", "icon.png")

locales.each do |locale|
  locale_path = File.join(temp_metadata_dir, locale)
  FileUtils.mkdir_p(locale_path) unless File.directory?(locale_path)
  
  # 1. Update Title dengan App Name proyek
  title_file = File.join(locale_path, "title.txt")
  File.write(title_file, app_name)
  puts "   📝 Title [#{locale}] diselaraskan -> '#{app_name}'"

  # 2. Update Icon jika custom icon berhasil disiapkan
  if has_custom_icon && File.exist?(project_icon_path)
    images_path = File.join(locale_path, "images")
    FileUtils.mkdir_p(images_path) unless File.directory?(images_path)
    dest_icon = File.join(images_path, "icon.png")
    FileUtils.cp(project_icon_path, dest_icon)
    puts "   🖼️  Icon [#{locale}] diselaraskan menggunakan custom icon project"
  else
    puts "   ℹ️  Icon [#{locale}] menggunakan icon bawaan template"
  end
end

# 7. Validation
puts "\n🔍 Melakukan validasi metadata sebelum mengunggah..."
validation_failed = false

locales.each do |locale|
  locale_path = File.join(temp_metadata_dir, locale)
  
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
  # Clean up before exit
  if temp_metadata_dir && File.directory?(temp_metadata_dir)
    puts "🧹 Membersihkan folder temporary: #{temp_metadata_dir}"
    FileUtils.rm_rf(temp_metadata_dir)
  end
  exit 1
end
puts "✅ Validasi metadata berhasil!"

# 8. Interactive Confirmation & Execution
begin
  puts "\n🚀 Memulai proses pengunggahan ke Google Play Store via Fastlane Supply..."
  
  require 'supply'
  
  # Supply requires metadata_path to point to the directory containing locale folders directly, 
  # which is our temp_metadata_dir
  options = {
    package_name: package_name,
    json_key: json_key,
    metadata_path: temp_metadata_dir,
    track: 'internal',                # Use internal track to avoid crashes on empty production track
    check_superseded_tracks: false,   # Disable track checking to avoid crashes
    skip_upload_apk: true,
    skip_upload_aab: true,
    skip_upload_changelogs: true,
    skip_upload_images: false,      # Allow upload if present
    skip_upload_screenshots: false   # Allow upload if present
  }
  
  Supply.config = FastlaneCore::Configuration.create(Supply::Options.available_options, options)
  
  # Monkey-patch Supply::Uploader to bypass track and release checks when skipping changelogs.
  # This fixes the crash where fetch_track_and_release! tries to call .size on nil when there are no releases.
  module Supply
    class Uploader
      def perform_upload_meta(version_codes, track_name)
        if (!Supply.config[:skip_upload_metadata] || !Supply.config[:skip_upload_images] || !Supply.config[:skip_upload_screenshots]) && metadata_path
          UI.message("Bypassing release/track checks to upload store listing metadata directly...")
          release_notes_queue = Queue.new
          upload_worker = create_meta_upload_worker
          
          # all_languages already ignores hidden folders like . or ..
          upload_jobs = all_languages.map { |lang| UploadJob.new(lang, nil, release_notes_queue) }
          upload_worker.batch_enqueue(upload_jobs)
          upload_worker.start
        end
      end
    end
  end
  
  upload_thread = Thread.new do
    Supply::Uploader.new.perform_upload
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
ensure
  if temp_metadata_dir && File.directory?(temp_metadata_dir)
    puts "\n🧹 Membersihkan folder temporary: #{temp_metadata_dir}"
    FileUtils.rm_rf(temp_metadata_dir)
  end
end
