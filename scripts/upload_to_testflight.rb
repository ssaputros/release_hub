#!/usr/bin/env ruby

require 'fastlane'
require 'spaceship'
require 'dotenv'
require 'json'
require 'tmpdir'
require 'open3'
require_relative 'app_store_connect_auth_helper'

# Muat file .env dari root directory
Dotenv.load(File.expand_path('../../.env', __FILE__))

DEFAULT_BUILD_WAIT_TIMEOUT = 30 * 60 # 30 menit, karena build TestFlight sering belum langsung muncul setelah upload IPA
DEFAULT_BUILD_POLL_INTERVAL = 30
DEFAULT_BUILD_INITIAL_DELAY = 60

def env_int(name, default_value, min: 0)
  raw_value = ENV[name]
  return default_value if raw_value.nil? || raw_value.to_s.strip.empty?

  value = raw_value.to_i
  value < min ? min : value
rescue
  default_value
end

def format_duration(seconds)
  seconds = seconds.to_i
  minutes = seconds / 60
  remainder = seconds % 60
  minutes.positive? ? "#{minutes}m #{remainder}s" : "#{remainder}s"
end

def plist_value(plist_path, key)
  stdout, _stderr, status = Open3.capture3('/usr/libexec/PlistBuddy', '-c', "Print :#{key}", plist_path)
  status.success? ? stdout.strip : nil
rescue
  nil
end

def extract_ipa_build_info(ipa_path)
  return {} if ipa_path.nil? || ipa_path.empty? || !File.exist?(ipa_path)

  Dir.mktmpdir('release_hub_ipa_info') do |tmpdir|
    _stdout, stderr, status = Open3.capture3('unzip', '-q', ipa_path, 'Payload/*.app/Info.plist', '-d', tmpdir)
    unless status.success?
      puts "⚠️ Gagal membaca Info.plist dari IPA: #{stderr.strip}"
      return {}
    end

    info_plist = Dir.glob(File.join(tmpdir, 'Payload', '*.app', 'Info.plist')).first
    unless info_plist && File.exist?(info_plist)
      puts '⚠️ Info.plist tidak ditemukan di dalam IPA; fallback ke build terbaru di App Store Connect.'
      return {}
    end

    {
      bundle_id: plist_value(info_plist, 'CFBundleIdentifier'),
      version: plist_value(info_plist, 'CFBundleShortVersionString'),
      build_number: plist_value(info_plist, 'CFBundleVersion')
    }.reject { |_key, value| value.nil? || value.empty? }
  end
rescue => e
  puts "⚠️ Gagal mengekstrak metadata IPA: #{e.message}"
  {}
end

def safe_attr(object, method_name)
  object.public_send(method_name)
rescue
  nil
end

def build_app_version(build)
  safe_attr(build, :app_version) || safe_attr(safe_attr(build, :pre_release_version), :version)
end

def build_processing_state(build)
  (safe_attr(build, :processing_state) || safe_attr(build, :processingState) || 'UNKNOWN').to_s
end

def describe_build(build)
  version = build_app_version(build) || 'Unknown'
  build_number = safe_attr(build, :version) || 'Unknown'
  "Versi #{version} (Build #{build_number})"
end

def build_matches_target?(build, target_info)
  return true if target_info.nil? || target_info.empty?

  target_build_number = target_info[:build_number]
  target_version = target_info[:version]
  candidate_build_number = safe_attr(build, :version).to_s
  candidate_version = build_app_version(build)&.to_s

  build_number_matches = target_build_number.nil? || target_build_number.empty? || candidate_build_number == target_build_number.to_s
  version_matches = target_version.nil? || target_version.empty? || candidate_version.nil? || candidate_version == target_version.to_s

  build_number_matches && version_matches
end

def latest_matching_build(app, target_info)
  builds = app.get_builds(
    filter: { processingState: 'PROCESSING,FAILED,VALID,INVALID' },
    includes: 'preReleaseVersion,buildBetaDetail',
    sort: '-uploadedDate',
    limit: 10
  )

  if target_info && !target_info.empty?
    builds.find { |candidate| build_matches_target?(candidate, target_info) }
  else
    builds.first
  end
rescue => e
  puts "⚠️ Gagal mengambil daftar build dari App Store Connect: #{e.message}"
  nil
end

def wait_for_build_processing(app, target_info, timeout:, interval:, initial_delay:)
  if target_info && !target_info.empty?
    puts "🎯 Target build dari IPA: #{target_info[:version] || 'Unknown'} (Build #{target_info[:build_number] || 'Unknown'})"
  else
    puts '⚠️ Target build dari IPA tidak terbaca; akan memakai build terbaru dari App Store Connect.'
  end

  if initial_delay.positive?
    puts "⏳ Menunggu #{format_duration(initial_delay)} agar build baru muncul di App Store Connect..."
    sleep initial_delay
  end

  start_time = Time.now
  last_message = nil

  loop do
    elapsed = (Time.now - start_time).to_i
    build = latest_matching_build(app, target_info)

    if build.nil?
      message = "Build target belum muncul di App Store Connect (elapsed #{format_duration(elapsed)})"
    else
      state = build_processing_state(build)
      message = "#{describe_build(build)} status '#{state}' (elapsed #{format_duration(elapsed)})"

      if build.processed?
        puts "\n✅ Build siap untuk submit: #{describe_build(build)}"
        return build
      end

      if %w[FAILED INVALID].include?(state.upcase)
        puts "\n❌ Build target ditemukan tetapi statusnya '#{state}'."
        return build
      end
    end

    if message != last_message
      puts "  - #{message}"
      last_message = message
    else
      print '.'
      STDOUT.flush
    end

    if elapsed >= timeout
      puts "\n⚠️ Timeout menunggu build siap setelah #{format_duration(timeout)}."
      return build
    end

    sleep interval
  end
end

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
apple_id = ENV['APPLE_ID_USERNAME']
project_root = File.expand_path('..', __dir__)

if (issuer_id.nil? || issuer_id.empty?) && (apple_id.nil? || apple_id.empty?)
  puts "❌ Konfigurasi App Store Connect belum lengkap di .env."
  puts "   Anda harus mengisi ASC_ISSUER_ID (API Key) ATAU APPLE_ID_USERNAME (Apple ID biasa)."
  exit 1
end

using_api_key = !(issuer_id.nil? || issuer_id.empty?)
key_filepath = AppStoreConnectAuthHelper.resolve_api_key_path(project_root: project_root) if using_api_key

begin
  AppStoreConnectAuthHelper.ensure_authenticated!(
    context: "Upload TestFlight #{app_name || app_identifier}",
    project_root: project_root
  )
  
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
    # Upload tetap dibuat non-blocking oleh pilot, lalu Release Hub sendiri yang polling
    # target build sampai benar-benar muncul/processed sebelum submit external.
    skip_waiting_for_build_processing: true
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
  
  AppStoreConnectAuthHelper.with_auth_retry(
    context: "Upload IPA TestFlight #{app_name || app_identifier}",
    project_root: project_root
  ) do
    if ENV['SKIP_UPLOAD'] == 'true'
      puts "⏭️ Melewati proses upload IPA karena SKIP_UPLOAD=true..."
    else
      AppStoreConnectAuthHelper.run_with_spinner('Mengunggah IPA ke Apple Server') do
        Pilot::BuildManager.new.upload(config)
      end
      puts "✅ Upload IPA selesai!"
    end
  end
  
  # Menyiapkan External Group
  group_name = "External Testers"
  puts "👥 Menyiapkan grup external: '#{group_name}'..."
  
  group = AppStoreConnectAuthHelper.with_auth_retry(
    context: "Setup grup TestFlight #{app_name || app_identifier}",
    project_root: project_root
  ) do
    current_group = app.get_beta_groups(filter: { name: group_name }).first
    if current_group.nil?
      # Buat grup jika belum ada
      current_group = app.create_beta_group(group_name: group_name, is_internal_group: false)
      puts "  - Grup '#{group_name}' berhasil dibuat."
    else
      puts "  - Grup '#{group_name}' sudah ada."
    end
    current_group
  end
  
  puts "🔍 Menunggu build TestFlight terbaru siap diproses..."
  target_build_info = extract_ipa_build_info(ipa_path)
  if target_build_info[:bundle_id] && target_build_info[:bundle_id] != app_identifier
    puts "⚠️ Bundle ID IPA (#{target_build_info[:bundle_id]}) berbeda dari target upload (#{app_identifier})."
  end

  wait_timeout = env_int('TESTFLIGHT_BUILD_WAIT_TIMEOUT', DEFAULT_BUILD_WAIT_TIMEOUT, min: 1)
  poll_interval = env_int('TESTFLIGHT_BUILD_POLL_INTERVAL', DEFAULT_BUILD_POLL_INTERVAL, min: 1)
  initial_delay = ENV['SKIP_UPLOAD'] == 'true' ? 0 : env_int('TESTFLIGHT_BUILD_INITIAL_DELAY', DEFAULT_BUILD_INITIAL_DELAY, min: 0)

  build = AppStoreConnectAuthHelper.with_auth_retry(
    context: "Menunggu build TestFlight #{app_name || app_identifier}",
    project_root: project_root
  ) do
    wait_for_build_processing(
      app,
      target_build_info,
      timeout: wait_timeout,
      interval: poll_interval,
      initial_delay: initial_delay
    )
  end
  
  if build.nil?
    puts "⚠️ Belum ada build target yang ditemukan untuk aplikasi ini."
    puts "❌ Build belum bisa disubmit ke TestFlight External."
    exit 2
  else
    state = build_processing_state(build)
    puts "  - Build target: #{describe_build(build)}"
    
    if %w[FAILED INVALID].include?(state.upcase)
      puts "❌ Build target berstatus '#{state}'. Periksa App Store Connect sebelum retry."
      exit 1
    elsif !build.processed?
      puts "⚠️ Build target masih berstatus '#{state}' setelah menunggu #{format_duration(wait_timeout)}."
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
        AppStoreConnectAuthHelper.with_auth_retry(
          context: "Submit TestFlight #{app_name || app_identifier}",
          project_root: project_root
        ) do
          # Tambahkan ke grup
          build.add_beta_groups(beta_groups: [group])
          puts "   ✅ Build berhasil ditambahkan ke grup!"
        end
        
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
          AppStoreConnectAuthHelper.with_auth_retry(
            context: "Update Beta Review Info #{app_name || app_identifier}",
            project_root: project_root
          ) do
            Spaceship::ConnectAPI.patch_beta_app_review_detail(app_id: app.id, attributes: attributes)
          end
          
          # 2. Update Beta App Localization (Description & Feedback Email)
          app_desc = review_info['app_description']
          if app_desc && !app_desc.empty?
            locs = AppStoreConnectAuthHelper.with_auth_retry(
              context: "Update TestFlight localization #{app_name || app_identifier}",
              project_root: project_root
            ) do
              app.get_beta_app_localizations
            end
            if locs.empty?
              # Buat lokalisasi baru jika belum ada
              client = Spaceship::ConnectAPI.client
              AppStoreConnectAuthHelper.with_auth_retry(
                context: "Create TestFlight localization #{app_name || app_identifier}",
                project_root: project_root
              ) do
                client.post_beta_app_localizations(app_id: app.id, attributes: { locale: "en-US", description: app_desc, feedbackEmail: ENV['EMAIL'] }) rescue nil
              end
            else
              # Update yang sudah ada
              AppStoreConnectAuthHelper.with_auth_retry(
                context: "Update TestFlight localization #{app_name || app_identifier}",
                project_root: project_root
              ) do
                locs.first.update(attributes: { description: app_desc, feedbackEmail: ENV['EMAIL'] })
              end
            end
          end
        rescue => e
          puts "   ⚠️ Gagal memperbarui Beta Review Info (Mungkin sudah tersetting): #{e.message}"
        end
        
        # Submit untuk Beta App Review (Wajib untuk External Testing)
        AppStoreConnectAuthHelper.with_auth_retry(
          context: "Submit Beta App Review #{app_name || app_identifier}",
          project_root: project_root
        ) do
          build.post_beta_app_review_submission
        end
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
      AppStoreConnectAuthHelper.with_auth_retry(
        context: "Aktifkan Public Link TestFlight #{app_name || app_identifier}",
        project_root: project_root
      ) do
        group.update(attributes: { publicLinkEnabled: true, publicLinkLimitEnabled: false })
      end
      # Refresh data group
      group = AppStoreConnectAuthHelper.with_auth_retry(
        context: "Refresh Public Link TestFlight #{app_name || app_identifier}",
        project_root: project_root
      ) do
        app.get_beta_groups(filter: { name: group_name }).first
      end
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
