#!/usr/bin/env ruby

require 'fastlane'
require 'spaceship'
require 'dotenv'
require 'json'

# Muat file .env dari root directory
Dotenv.load(File.expand_path('../../.env', __FILE__))

ipa_path = ARGV[0]
app_identifier = ARGV[1]
app_name = ARGV[2]
app_type = ARGV[3]

if ipa_path.nil? || app_identifier.nil?
  puts "Usage: ruby upload_to_testflight.rb <ipa_path> <app_identifier> [app_name] [app_type]"
  exit 1
end

# Membaca config.json untuk info beta review
config_file = File.expand_path('../../config.json', __FILE__)
review_info = {}
if File.exist?(config_file) && !app_type.nil? && !app_type.empty?
  begin
    config_data = JSON.parse(File.read(config_file))
    review_info = config_data.dig('types', app_type, 'beta_app_review_info') || {}
  rescue => e
    puts "⚠️ Gagal membaca config.json: #{e.message}"
  end
end

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
  key_filepath = File.expand_path("../../#{key_filepath}", __FILE__)
  if !File.exist?(key_filepath)
    puts "❌ File API Key tidak ditemukan di: #{key_filepath}"
    exit 1
  end
end

begin
  if using_api_key
    puts "🔑 Melakukan otentikasi menggunakan API Key..."
    token = Spaceship::ConnectAPI::Token.create(
      key_id: key_id,
      issuer_id: issuer_id,
      filepath: key_filepath
    )
    Spaceship::ConnectAPI.token = token
  else
    puts "🔑 Melakukan otentikasi menggunakan Apple ID (#{apple_id})..."
    puts "   (Jika diminta, masukkan password dan kode OTP/2FA di terminal)"
    
    ENV['FASTLANE_USER'] = apple_id
    ENV['FASTLANE_ITC_TEAM_ID'] = ENV['ITC_TEAM_ID'] unless ENV['ITC_TEAM_ID'].nil? || ENV['ITC_TEAM_ID'].empty?
    ENV.delete('FASTLANE_TEAM_ID') # Jangan set ini secara global agar Spaceship Connect API tidak salah baca
    
    Spaceship::ConnectAPI.login(apple_id)
  end
  
  # Cari App
  app = Spaceship::ConnectAPI::App.find(app_identifier)
  if app.nil?
    puts "❌ App dengan bundle ID #{app_identifier} tidak ditemukan di App Store Connect."
    puts "⚠️ Pastikan Anda sudah membuat App ini (misalnya dengan init_appstore.sh) sebelum mengunggah build."
    exit 1
  end

  puts "🚀 Mengunggah #{File.basename(ipa_path)} ke TestFlight..."
  
  require 'pilot'
  
  # Konfigurasi Upload Pilot
  options = {
    app_identifier: app_identifier,
    ipa: ipa_path,
    skip_waiting_for_build_processing: true # Skrip tidak akan terblokir menunggu Apple
  }
  
  if using_api_key
    options[:api_key_path] = key_filepath
  else
    options[:username] = apple_id
    options[:team_id] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
    options[:itc_provider] = ENV['ITC_TEAM_ID'] if ENV['ITC_TEAM_ID']
    options[:dev_portal_team_id] = ENV['TEAM_ID'] if ENV['TEAM_ID']
    
    puts "\n⚠️ CATATAN UNTUK UPLOAD DENGAN APPLE ID:"
    puts "Jika upload gagal di tengah jalan dengan error 'Application Specific Password',"
    puts "pastikan Anda telah men-generate App-Specific Password di appleid.apple.com"
    puts "dan menambahkannya di .env Anda sebagai:"
    puts "FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=\"password-anda\"\n\n"
  end

  config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
  
  if ENV['SKIP_UPLOAD'] == 'true'
    puts "⏭️ Melewati proses upload IPA karena SKIP_UPLOAD=true..."
  else
    upload_thread = Thread.new do
      Pilot::BuildManager.new.upload(config)
    end
    
    # Tunggu sebentar agar log awal Fastlane tercetak, lalu beri baris baru
    sleep 2
    puts "" 
    
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0
    start_time = Time.now
    while upload_thread.alive?
      elapsed = (Time.now - start_time).to_i
      mins = elapsed / 60
      secs = elapsed % 60
      print "\r⏳ #{spinner[i % spinner.length]} Mengunggah IPA ke Apple Server... (Waktu berlalu: #{mins}m #{secs}s)   "
      i += 1
      sleep 0.2
    end
    
    upload_thread.join
    puts "\n✅ Upload IPA selesai!"
  end
  
  # Menyiapkan External Group
  group_name = "External Testers"
  puts "👥 Menyiapkan grup external: '#{group_name}'..."
  
  group = app.get_beta_groups(filter: { name: group_name }).first
  if group.nil?
    # Buat grup jika belum ada
    group = app.create_beta_group(group_name: group_name, is_internal_group: false)
    puts "  - Grup '#{group_name}' berhasil dibuat."
  else
    puts "  - Grup '#{group_name}' sudah ada."
  end
  
  puts "🔍 Mengecek status Build terbaru..."
  build = app.get_builds(
    filter: { processingState: "PROCESSING,FAILED,VALID,INVALID" },
    includes: "preReleaseVersion,buildBetaDetail", 
    sort: "-uploadedDate", 
    limit: 1
  ).first
  
  if build.nil?
    puts "⚠️ Belum ada build yang ditemukan untuk aplikasi ini."
  else
    version_string = build.app_version rescue "Unknown"
    puts "  - Build terbaru: Versi #{version_string} (Build #{build.version})"
    
    if !build.processed?
      puts "⚠️ Build terbaru masih berstatus '#{build.processing_state}' (sedang diproses Apple)."
      puts "❌ Build belum bisa disubmit ke TestFlight External."
      exit 2
    else
      puts "📦 Menambahkan build #{build.version} ke grup '#{group_name}'..."
      # Menyatakan bebas enkripsi (Export Compliance) jika diminta Apple
      begin
        if build.missing_export_compliance?
          build.update(attributes: { usesNonExemptEncryption: false })
        end
      rescue => e
        puts "   ℹ️ (Melewati pengecekan enkripsi: #{e.message})"
      end
      
      begin
        # Tambahkan ke grup
        build.add_beta_groups(beta_groups: [group])
        puts "   ✅ Build berhasil ditambahkan ke grup!"
        
        # Set Beta App Review Details & Description
        puts "   📝 Menyiapkan informasi Beta App Review & Deskripsi..."
        begin
          # 1. Update Beta App Review Detail (Contact & Demo Account)
          attributes = {
            contactFirstName: ENV['FIRST_NAME'],
            contactLastName: ENV['LAST_NAME'],
            contactEmail: ENV['EMAIL'],
            contactPhone: ENV['PHONE_NUMBER'],
            demoAccountName: review_info['username'],
            demoAccountPassword: review_info['password'],
            demoAccountRequired: true
          }
          # Hilangkan kunci yang kosong agar tidak error
          attributes.reject! { |k, v| v.nil? || v.to_s.empty? }
          Spaceship::ConnectAPI.patch_beta_app_review_detail(app_id: app.id, attributes: attributes)
          
          # 2. Update Beta App Localization (Description & Feedback Email)
          app_desc = review_info['app_description']
          if app_desc && !app_desc.empty?
            locs = app.get_beta_app_localizations
            if locs.empty?
              # Buat lokalisasi baru jika belum ada
              client = Spaceship::ConnectAPI.client
              client.post_beta_app_localizations(app_id: app.id, attributes: { locale: "en-US", description: app_desc, feedbackEmail: ENV['EMAIL'] }) rescue nil
            else
              # Update yang sudah ada
              locs.first.update(attributes: { description: app_desc, feedbackEmail: ENV['EMAIL'] })
            end
          end
        rescue => e
          puts "   ⚠️ Gagal memperbarui Beta Review Info (Mungkin sudah tersetting): #{e.message}"
        end
        
        # Submit untuk Beta App Review (Wajib untuk External Testing)
        build.post_beta_app_review_submission
        puts "   ✅ Build berhasil di-submit untuk Beta App Review!"
      rescue => e
        puts "   ℹ️ Info Assign/Review: #{e.message}"
      end
    end
  end
  
  # Mengaktifkan Public Link
  unless group.public_link_enabled
    puts "🔗 Mengaktifkan Public Link..."
    begin
      # Menggunakan metode bawaan BetaGroup untuk mengaktifkan public link
      group.update(attributes: { publicLinkEnabled: true, publicLinkLimitEnabled: false })
      # Refresh data group
      group = app.get_beta_groups(filter: { name: group_name }).first
    rescue => e
      puts "  ⚠️ Gagal mengaktifkan Public Link otomatis: #{e.message}"
      puts "     (Terkadang Apple memblokir ini untuk Fresh App sebelum Beta Review)"
    end
  end

  if group.public_link
    puts "\n============================================================"
    puts "🎉 TESTFLIGHT PUBLIC LINK"
    puts "============================================================"
    puts "🔗 #{group.public_link}"
    puts "============================================================"
  else
    puts "\n============================================================"
    puts "⚠️ PUBLIC LINK BELUM TERSEDIA AKTIF"
    puts "============================================================"
    puts "Aplikasi ini berstatus 'Fresh App'. Apple mewajibkan agar"
    puts "build pertama ini melalui proses 'Beta App Review' terlebih"
    puts "dahulu. Setelah disetujui (biasanya 1-2 hari), Public Link"
    puts "akan aktif di dashboard App Store Connect Anda."
    puts "============================================================"
  end
  
rescue => e
  puts "❌ Terjadi kesalahan: #{e.message}"
  exit 1
end
