#!/usr/bin/env ruby

require 'json'
require 'fileutils'

if ARGV.length < 2
  puts "Usage: ruby submit_playstore_version.rb <target_id> <app_type>"
  exit 1
end

target_id = ARGV[0]
app_type = ARGV[1]

script_dir = File.expand_path("..", __dir__)
project_file = File.join(script_dir, "projects.json")

unless File.exist?(project_file)
  puts "❌ Error: projects.json tidak ditemukan."
  exit 1
end

projects = JSON.parse(File.read(project_file))
project_data = projects[target_id]

unless project_data
  puts "❌ Error: Project dengan ID '#{target_id}' tidak ditemukan."
  exit 1
end

project_name = project_data.dig("Project", "Project Name")
app_names = project_data.dig("Project", "App Name")
app_name = app_names.is_a?(Hash) ? app_names[app_type] : app_names

package_ids = project_data["Package ID"]
package_name = package_ids.is_a?(Hash) ? package_ids[app_type] : package_ids

unless package_name
  puts "❌ Error: Package ID tidak ditemukan untuk tipe '#{app_type}' pada project '#{target_id}'."
  exit 1
end

target_dir = File.join(script_dir, "build_result", project_name, app_type)

# Cari file AAB yang mengandung nama aplikasi (case-insensitive search for safety)
# Escape karakter khusus pada app_name
safe_app_name = app_name.gsub(/[^0-9A-Za-z.\- ]/, '')
aab_files = Dir.glob(File.join(target_dir, "*.aab")).select do |f|
  File.basename(f).downcase.include?(safe_app_name.downcase)
end

if aab_files.empty?
  puts "❌ Error: File AAB untuk '#{app_name}' tidak ditemukan di #{target_dir}."
  puts "💡 Pastikan Anda sudah menjalankan opsi Build AAB terlebih dahulu."
  exit 1
end

# Ambil yang terbaru berdasarkan waktu modifikasi
latest_aab = aab_files.max_by { |f| File.mtime(f) }

puts "============================================================"
puts "🚀 MEMULAI SUBMIT AAB PLAY STORE"
puts "============================================================"
puts "Project    : #{project_name}"
puts "App Name   : #{app_name}"
puts "Package ID : #{package_name}"
puts "File AAB   : #{File.basename(latest_aab)}"
puts "------------------------------------------------------------"

upload_script = File.join(script_dir, "scripts", "upload_to_playstore.rb")
cmd = "ruby \"#{upload_script}\" \"#{latest_aab}\" \"#{package_name}\" \"internal\""

unless system(cmd)
  puts "❌ Gagal mengunggah ke Play Store."
  exit 1
end

puts "🎉 Submit AAB Play Store selesai!"
