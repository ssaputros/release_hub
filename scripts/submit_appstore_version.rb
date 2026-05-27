require 'spaceship'

require 'spaceship'
require 'json'
require 'fileutils'

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

bundle_id = app_data['Bundle ID'][app_type]
if bundle_id.nil? || bundle_id.empty?
  puts "❌ Error: Bundle ID tidak ditemukan untuk tipe #{app_type}."
  exit 1
end

puts "\n============================================================"
puts "🍎 SUBMIT APP STORE VERSION"
puts "============================================================"
puts "Project       : #{app_data['Project']['Project Name']}"
puts "App Type      : #{app_type}"
puts "Bundle ID     : #{bundle_id}"
puts "------------------------------------------------------------"

puts "⏳ Menghubungkan ke App Store Connect..."
begin
  Spaceship::ConnectAPI.login
rescue => e
  puts "❌ Gagal login ke App Store Connect: #{e.message}"
  exit 1
end

app = Spaceship::ConnectAPI::App.find(bundle_id)

if app.nil?
  puts "❌ Aplikasi dengan Bundle ID '#{bundle_id}' tidak ditemukan di App Store Connect."
  exit 1
end

# 1. Dapatkan build terakhir yang valid (sudah diproses)
puts "🔍 Mencari build terbaru yang sudah diproses..."
builds = app.get_builds(filter: { processingState: "VALID" }, sort: "-uploadedDate", includes: "preReleaseVersion")
latest_build = builds.first

if latest_build.nil?
  puts "❌ Tidak ada build yang tersedia (atau belum selesai diproses) untuk disubmit."
  exit 1
end

version_string = latest_build.app_version
build_number = latest_build.version

puts "✅ Build terakhir ditemukan: Versi #{version_string} (Build #{build_number})"

# 2. Cek apakah ini aplikasi baru (First Version) atau bukan
live_version = app.get_live_app_store_version
edit_version = app.get_edit_app_store_version

if live_version.nil?
  puts "ℹ️ Ini adalah versi pertama aplikasi di App Store."
  if edit_version.nil?
    puts "🔄 Membuat versi pertama: #{version_string}..."
    edit_version = app.create_app_store_version(version_string: version_string, platform: "IOS")
  else
    puts "ℹ️ Menggunakan versi draft yang sudah ada. Menyesuaikan versi ke #{version_string}..."
    begin
      edit_version.update(attributes: { versionString: version_string })
    rescue => e
      puts "⚠️ Peringatan saat update versi (biasanya aman diabaikan): #{e.message}"
    end
  end
else
  puts "ℹ️ Aplikasi sudah memiliki versi live: #{live_version.version_string}"
  if edit_version.nil?
    puts "🔄 Membuat versi App Store baru: #{version_string}..."
    edit_version = app.create_app_store_version(version_string: version_string, platform: "IOS")
  else
    puts "ℹ️ Versi draft (Prepare for Submission) sudah ada. Menyesuaikan versi ke #{version_string}..."
    begin
      edit_version.update(attributes: { versionString: version_string })
    rescue => e
      puts "⚠️ Peringatan saat update versi (biasanya aman diabaikan): #{e.message}"
    end
  end
end

# 3. Tetapkan build ke versi ini
puts "🔄 Menetapkan Build #{build_number} ke versi #{version_string}..."
begin
  edit_version.select_build(build_id: latest_build.id)
rescue => e
  puts "⚠️ Peringatan saat menetapkan build (mungkin sudah ditetapkan): #{e.message}"
end

# 4. Submit untuk review
puts "🚀 Mengirimkan aplikasi untuk App Review..."
begin
  # 1. Cari Review Submission yang masih draft atau buat yang baru
  submission = app.get_review_submissions(filter: { state: 'READY_FOR_REVIEW' }).first
  if submission.nil?
    submission = app.create_review_submission(platform: 'IOS')
  end
  
  # 2. Tambahkan App Store Version ke dalam Review Submission
  begin
    submission.add_app_store_version_to_review_items(app_store_version_id: edit_version.id)
  rescue => e
    # Abaikan peringatan jika versi sudah otomatis dimasukkan ke dalam draft
  end

  # 3. Eksekusi pengiriman untuk Review
  submission.submit_for_review
  puts "🎉 Berhasil! Aplikasi Anda telah diajukan untuk review."
rescue => e
  if e.message.include?("already been submitted") || e.message.include?("Waiting for Review") || e.message.include?("does not allow 'CREATE'") || e.message.include?("already in review")
    puts "🎉 Aplikasi sudah dalam status submitted (Waiting for Review)."
  else
    puts "❌ Gagal mensubmit aplikasi: #{e.message}"
    puts "Pastikan Anda telah mengisi seluruh kelengkapan App Store Info (Pricing, Privacy, dll)."
    exit 1
  end
end
