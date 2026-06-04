#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'readline'

# Helper method untuk prompt dengan default value
def prompt(text, default = "")
  p = default.empty? ? "#{text}: " : "#{text} [#{default}]: "
  input = Readline.readline(p, true).strip
  input.empty? ? default : input
end

# Helper method untuk parse .env format dari string
def parse_env(env_string)
  env_hash = {}
  env_string.each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    if line =~ /^([^=]+)="?(.*?)"?$/
      key, value = $1, $2
      env_hash[key] = value
    end
  end
  env_hash
end

# Dapatkan konfigurasi direktori
script_dir = File.expand_path("..", __dir__)
config_path = File.join(script_dir, "config.json")
projects_path = File.join(script_dir, "projects.json")

unless File.exist?(config_path)
  puts "❌ config.json tidak ditemukan!"
  exit 1
end

config = JSON.parse(File.read(config_path))
projects = JSON.parse(File.read(projects_path))

puts "============================================================"
puts "🔄 IMPORT PROJECT FROM BRANCH"
puts "============================================================"

# Simpan data yang akan digabung
project_data = {
  "Branch" => {},
  "Project" => {
    "App Name" => {}
  },
  "Play Console Dashboard" => {},
  "Package ID" => {},
  "Bundle ID" => {}
}

types_found = []
base_url = ""
database = ""
project_id_guess = ""

["HRM Apps", "Approval Apps"].each do |app_type|
  type_config = config.dig("types", app_type)
  next unless type_config && type_config["location"]

  repo_path = File.expand_path(type_config["location"])
  next unless Dir.exist?(repo_path)

  branch = prompt("Masukkan branch untuk #{app_type} (kosongkan jika skip)")
  next if branch.empty?

  puts "🔍 Mengekstrak data dari branch #{branch} di #{app_type}..."
  
  # Coba ambil .env dari origin terlebih dahulu, jika gagal coba lokal
  env_content = `git -C "#{repo_path}" show origin/#{branch}:.env 2>/dev/null`
  if !$?.success?
    env_content = `git -C "#{repo_path}" show #{branch}:.env 2>/dev/null`
  end

  if env_content.nil? || env_content.empty?
    puts "⚠️ Gagal menemukan file .env di branch #{branch} untuk #{app_type}."
    next
  end

  env_hash = parse_env(env_content)
  
  project_data["Branch"][app_type] = branch
  project_data["Project"]["App Name"][app_type] = env_hash["APP_NAME"] if env_hash["APP_NAME"]
  project_data["Package ID"][app_type] = env_hash["ANDROID_ID"] if env_hash["ANDROID_ID"]
  project_data["Bundle ID"][app_type] = env_hash["IOS_ID"] || env_hash["ANDROID_ID"]
  
  base_url = env_hash["BASE_URL"] if base_url.empty? && env_hash["BASE_URL"]
  database = env_hash["DEFAULT_DB"] if database.empty? && env_hash["DEFAULT_DB"]
  
  if project_id_guess.empty? && env_hash["ANDROID_ID"]
    project_id_guess = env_hash["ANDROID_ID"].split('.').last
  end
  
  types_found << app_type
  puts "✅ Berhasil membaca .env dari #{app_type}."
end

if types_found.empty?
  puts "❌ Tidak ada data yang berhasil diimport dari branch manapun."
  exit 1
end

puts "\n============================================================"
puts "📝 KONFIRMASI DATA PROJECT"
puts "============================================================"

project_id = prompt("ID Project", project_id_guess)
project_name = prompt("Project Name", project_id.capitalize)
region = prompt("Region", "Indonesia")
base_url = prompt("Base URL", base_url)
database = prompt("Database", database)

project_data["Project"]["Project Name"] = project_name
project_data["Project"]["Region"] = region
project_data["Project"]["Type"] = types_found.join(", ")
project_data["Project"]["Base URL"] = base_url
project_data["Project"]["Database"] = database
project_data["Project"]["Icon"] = ""

puts "\nData yang akan disimpan untuk ID '#{project_id}':"
puts JSON.pretty_generate(project_data)

confirm = prompt("Apakah Anda yakin ingin menyimpan data ini ke projects.json? (y/n)", "y")
if confirm.downcase == 'y'
  projects[project_id] = project_data
  File.write(projects_path, JSON.pretty_generate(projects) + "\n")
  puts "✅ Project '#{project_id}' berhasil ditambahkan ke projects.json!"
else
  puts "❌ Dibatalkan."
end
