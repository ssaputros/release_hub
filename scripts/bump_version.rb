#!/usr/bin/env ruby

require 'json'
require 'fileutils'

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

unless File.exist?(config_path)
  puts "❌ Error: config.json tidak ditemukan."
  exit 1
end

projects = JSON.parse(File.read(projects_path))
config = JSON.parse(File.read(config_path))

# 3. Handle arguments or interactive selection
run_id = ARGV[0]

if run_id.nil? || run_id.empty?
  puts "============================================================"
  puts "🔢 PILIH PROJECT UNTUK BUMP VERSION"
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

app_type = (app_data['Project']['Type'] || "").split(",").first.strip
location_raw = config['types'][app_type]['location']
unless location_raw
  puts "❌ Error: Lokasi aplikasi untuk tipe '#{app_type}' tidak ditemukan di config.json."
  exit 1
end

project_location = File.expand_path(location_raw)
pubspec_path = File.join(project_location, "pubspec.yaml")

unless File.exist?(pubspec_path)
  puts "❌ Error: pubspec.yaml tidak ditemukan di lokasi project: #{project_location}"
  exit 1
end

# 4. Read & Parse Current Version
pubspec_content = File.read(pubspec_path)
version_match = pubspec_content.match(/^version:\s*([^\s#]+)/)

unless version_match
  puts "❌ Error: Baris versi ('version:') tidak ditemukan di pubspec.yaml."
  exit 1
end

current_version = version_match[1]
puts "\n============================================================"
puts "📈 BUMP VERSION FOR: #{app_data['Project']['App Name']}"
puts "============================================================"
puts "Lokasi Project : #{project_location}"
puts "Versi Saat Ini : #{current_version}"
puts "============================================================"

# Parse version (e.g. 1.3.3+6)
unless current_version =~ /^(\d+)\.(\d+)\.(\d+)\+(\d+)$/
  puts "❌ Error: Format versi saat ini tidak didukung ('#{current_version}'). Harus format 'major.minor.patch+build'."
  exit 1
end

major = $1.to_i
minor = $2.to_i
patch = $3.to_i
build = $4.to_i

# 5. Show Bump Options
puts "Pilih metode bump version:"
puts "1) Bump Release (Naikkan Build Number & Patch)"
puts "   Contoh: #{current_version} -> #{major}.#{minor}.#{patch + 1}+#{build + 1}"
puts "2) Bump Biasa (Hanya naikkan Build Number saja)"
puts "   Contoh: #{current_version} -> #{major}.#{minor}.#{patch}+#{build + 1}"
puts "0) Batal"
puts "------------------------------------------------------------"
print "Pilihan Anda (1/2/0): "
bump_choice = $stdin.gets.chomp.strip

if bump_choice == '0' || bump_choice.empty?
  puts "Batal."
  exit 0
end

new_version = ""
if bump_choice == '1'
  new_patch = patch + 1
  new_build = build + 1
  new_version = "#{major}.#{minor}.#{new_patch}+#{new_build}"
elsif bump_choice == '2'
  new_build = build + 1
  new_version = "#{major}.#{minor}.#{patch}+#{new_build}"
else
  puts "❌ Pilihan tidak valid."
  exit 1
end

# 6. Apply & Save Changes
puts "\n🔄 Memproses bump version..."
puts "   Sebelum: #{current_version}"
puts "   Sesudah: #{new_version}"

# A. Update pubspec.yaml
new_pubspec_content = pubspec_content.sub(/^version:\s*[^\s#]+/, "version: #{new_version}")
File.write(pubspec_path, new_pubspec_content)
puts "📝 Berhasil memperbarui pubspec.yaml ke: #{new_version}"

# B. Update .env file if it exists (for Hrm Apps environment bump)
env_path = File.join(project_location, ".env")
if File.exist?(env_path)
  env_content = File.read(env_path)
  # Look for APP_VERSION line (match double/single quotes or raw values)
  # Match format: APP_VERSION="something 1.2.3+4" or APP_VERSION=something_1.2.3+4
  app_version_regex = /^(APP_VERSION\s*=\s*(["'])?)(.*?)((\d+\.\d+\.\d+\+\d+)?)(["'])?$/
  
  if env_content =~ /^APP_VERSION\s*=\s*.+$/
    line = $&
    
    # Simple replace the version part at the end of the line
    if line =~ /(\d+\.\d+\.\d+\+\d+)/
      old_v = $1
      new_line = line.sub(old_v, new_version)
      env_content = env_content.sub(line, new_line)
      File.write(env_path, env_content)
      puts "📝 Berhasil memperbarui APP_VERSION di .env ke: #{new_line.split('=').last.strip}"
    else
      # If version part not matched but APP_VERSION exists, just overwrite it
      new_line = "APP_VERSION=\"$APP_NAME #{new_version}\""
      env_content = env_content.sub(line, new_line)
      File.write(env_path, env_content)
      puts "📝 Berhasil menulis ulang APP_VERSION di .env ke: #{new_line.split('=').last.strip}"
    end
  end
end

puts "\n✅ Selesai melakukan bump version!"
puts "============================================================\n"
