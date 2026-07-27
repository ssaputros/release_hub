#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'timeout'
require 'fileutils'
require 'time'

script_dir = __dir__
project_root = File.expand_path('..', script_dir)

begin
  require 'dotenv'
  Dotenv.load(File.join(project_root, '.env'))
rescue LoadError
  # release_hub normally has dotenv through fastlane; if unavailable, keep using exported env.
end

require_relative 'app_store_connect_auth_helper'

context = ENV['RELEASE_HUB_AUTH_CONTEXT'].to_s.strip
context = 'App Store Connect' if context.empty?
result_file = ENV['RELEASE_HUB_AUTH_RESULT_FILE']

def write_result(path, payload)
  return if path.nil? || path.empty?

  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(payload))
rescue => e
  warn "⚠️ Gagal menulis status auth: #{e.message}"
end

puts "============================================================"
puts "🔐 RELEASE HUB - APP STORE CONNECT AUTHENTICATION"
puts "============================================================"
puts "Context : #{context}"
puts "Apple ID: #{AppStoreConnectAuthHelper.apple_id || '(not configured)'}"
puts ""
puts "Silakan selesaikan login/password/2FA di window Terminal ini jika diminta."
puts "Setelah sukses, Release Hub akan otomatis retry/lanjut di proses sebelumnya."
puts "============================================================"
puts ""

begin
  if AppStoreConnectAuthHelper.using_api_key?
    AppStoreConnectAuthHelper.authenticate_with_api_key!(project_root: project_root)
  else
    AppStoreConnectAuthHelper.configure_fastlane_env!
    timeout_seconds = AppStoreConnectAuthHelper.env_int(
      'RELEASE_HUB_ASC_FOREGROUND_AUTH_TIMEOUT',
      15 * 60,
      min: 60
    )

    puts "⏳ Menghubungkan ke App Store Connect..."
    Timeout.timeout(timeout_seconds) do
      require 'spaceship'
      Spaceship::ConnectAPI.login(
        AppStoreConnectAuthHelper.apple_id,
        **AppStoreConnectAuthHelper.login_options
      )
    end
  end

  puts ""
  puts "✅ Autentikasi App Store Connect berhasil."
  puts "Window ini boleh ditutup; Release Hub akan melanjutkan proses."
  write_result(result_file, { status: 'success', context: context, finished_at: Time.now.utc.iso8601 })
  sleep 2
  exit 0
rescue => e
  puts ""
  puts "❌ Autentikasi App Store Connect gagal: #{e.message}"
  puts "Perbaiki login/2FA/session lalu jalankan ulang proses Release Hub."
  write_result(result_file, { status: 'error', context: context, message: e.message, finished_at: Time.now.utc.iso8601 })
  puts "Tekan Enter untuk menutup window ini..."
  begin
    STDIN.gets
  rescue
    sleep 5
  end
  exit 1
end
