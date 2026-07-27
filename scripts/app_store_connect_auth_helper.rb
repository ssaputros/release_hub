# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'timeout'
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'net/http'
require 'uri'

begin
  require 'dotenv'
  Dotenv.load(File.expand_path('../.env', __dir__))
rescue LoadError
  # dotenv is optional here; scripts may already export the needed env vars.
end

module AppStoreConnectAuthHelper
  DEFAULT_LOGIN_PROBE_TIMEOUT = 45
  TELEGRAM_ENV_KEYS = %w[
    TELEGRAM_BOT_TOKEN
    TELEGRAM_HOME_CHANNEL
    TELEGRAM_HOME_CHANNEL_THREAD_ID
  ].freeze

  module_function

  def present?(value)
    !value.nil? && !value.to_s.strip.empty?
  end

  def env_int(name, default_value, min: 0)
    raw_value = ENV[name]
    return default_value unless present?(raw_value)

    value = raw_value.to_i
    value < min ? min : value
  rescue
    default_value
  end

  def using_api_key?
    present?(ENV['ASC_ISSUER_ID'])
  end

  def apple_id
    ENV['APPLE_ID_USERNAME']
  end

  def resolve_api_key_path(key_file = ENV['ASC_KEY_FILE'], project_root:)
    return nil unless present?(key_file)

    File.expand_path(key_file, project_root)
  end

  def authenticate_with_api_key!(project_root:)
    issuer_id = ENV['ASC_ISSUER_ID']
    key_id = ENV['ASC_KEY_ID']
    key_filepath = resolve_api_key_path(project_root: project_root)

    unless present?(issuer_id) && present?(key_id) && present?(key_filepath)
      raise 'Konfigurasi ASC_ISSUER_ID / ASC_KEY_ID / ASC_KEY_FILE belum lengkap.'
    end

    unless File.exist?(key_filepath)
      raise "File API Key tidak ditemukan di: #{key_filepath}"
    end

    require 'spaceship'
    puts '🔑 Melakukan otentikasi App Store Connect menggunakan API Key...'
    token = Spaceship::ConnectAPI::Token.create(
      key_id: key_id,
      issuer_id: issuer_id,
      filepath: key_filepath
    )
    Spaceship::ConnectAPI.token = token
    key_filepath
  end

  def configure_fastlane_env!
    raise 'APPLE_ID_USERNAME belum terisi di .env.' unless present?(apple_id)

    ENV['FASTLANE_USER'] = apple_id
    ENV['FASTLANE_ITC_TEAM_ID'] = ENV['ITC_TEAM_ID'] if present?(ENV['ITC_TEAM_ID'])
    # ConnectAPI team selection is handled through explicit login_options below.
    # Keeping FASTLANE_TEAM_ID globally can make Spaceship choose the wrong team in multi-team accounts.
    ENV.delete('FASTLANE_TEAM_ID')
    ENV['FASTLANE_SKIP_UPDATE_CHECK'] = 'true' unless present?(ENV['FASTLANE_SKIP_UPDATE_CHECK'])
  end

  def login_options
    options = { skip_select_team: true }
    options[:portal_team_id] = ENV['TEAM_ID'] if present?(ENV['TEAM_ID'])
    options[:tunes_team_id] = ENV['ITC_TEAM_ID'] if present?(ENV['ITC_TEAM_ID'])
    options
  end

  def direct_apple_id_login!(timeout_seconds: nil)
    require 'spaceship'
    configure_fastlane_env!
    timeout_seconds ||= env_int('RELEASE_HUB_ASC_LOGIN_PROBE_TIMEOUT', DEFAULT_LOGIN_PROBE_TIMEOUT, min: 1)

    Timeout.timeout(timeout_seconds) do
      Spaceship::ConnectAPI.login(apple_id, **login_options)
    end
  end

  def auth_error?(error)
    message = if error.respond_to?(:message)
                error.message.to_s
              else
                error.to_s
              end

    patterns = [
      /auth/i,
      /login/i,
      /session/i,
      /credential/i,
      /password/i,
      /2fa/i,
      /two[- ]?factor/i,
      /two[- ]?step/i,
      /verification/i,
      /unauthori[sz]ed/i,
      /forbidden/i,
      /not logged in/i,
      /invalid.*user/i,
      /Your Apple ID or password/i,
      /Application Specific Password/i,
      /Need to acknowledge/i,
      /Access forbidden/i
    ]
    patterns.any? { |pattern| message.match?(pattern) }
  end

  def env_truthy?(name)
    %w[1 true yes y].include?(ENV[name].to_s.strip.downcase)
  end

  def foreground_auth_disabled?
    env_truthy?('RELEASE_HUB_DISABLE_FOREGROUND_AUTH')
  end

  def telegram_auth_notify_disabled?
    env_truthy?('RELEASE_HUB_DISABLE_TELEGRAM_AUTH_NOTIFY') ||
      ENV['RELEASE_HUB_TELEGRAM_AUTH_NOTIFY'].to_s.strip.downcase == 'false'
  end

  def load_hermes_telegram_env!
    return if defined?(@telegram_env_loaded) && @telegram_env_loaded

    @telegram_env_loaded = true
    hermes_home = ENV['HERMES_HOME']
    hermes_home = File.expand_path('~/.hermes') unless present?(hermes_home)
    env_files = []
    env_files << ENV['RELEASE_HUB_TELEGRAM_ENV_FILE'] if present?(ENV['RELEASE_HUB_TELEGRAM_ENV_FILE'])
    env_files << File.join(hermes_home, '.env')

    env_files.uniq.each do |env_file|
      next unless present?(env_file) && File.file?(env_file)

      File.readlines(env_file, chomp: true).each do |line|
        key, value = parse_env_line(line)
        next unless TELEGRAM_ENV_KEYS.include?(key)
        next if present?(ENV[key])

        ENV[key] = value if present?(value)
      end
    end
  rescue => e
    warn "⚠️ Gagal membaca konfigurasi Telegram Hermes untuk auth notify (#{e.class})."
  end

  def parse_env_line(line)
    return [nil, nil] if line.strip.empty? || line.lstrip.start_with?('#')

    match = line.match(/\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/)
    return [nil, nil] unless match

    key = match[1]
    value = match[2].to_s.strip
    if value.length >= 2 && ((value.start_with?('"') && value.end_with?('"')) ||
                             (value.start_with?("'") && value.end_with?("'")))
      value = value[1...-1]
    end
    [key, value]
  end

  def telegram_auth_notification_config
    load_hermes_telegram_env!

    token = ENV['RELEASE_HUB_TELEGRAM_BOT_TOKEN']
    token = ENV['TELEGRAM_BOT_TOKEN'] unless present?(token)

    chat_id = ENV['RELEASE_HUB_TELEGRAM_CHAT_ID']
    chat_id = ENV['HERMES_SESSION_CHAT_ID'] unless present?(chat_id)
    chat_id = ENV['TELEGRAM_HOME_CHANNEL'] unless present?(chat_id)

    thread_id = ENV['RELEASE_HUB_TELEGRAM_THREAD_ID']
    thread_id = ENV['HERMES_SESSION_THREAD_ID'] unless present?(thread_id)
    thread_id = ENV['TELEGRAM_HOME_CHANNEL_THREAD_ID'] unless present?(thread_id)

    { token: token, chat_id: chat_id, thread_id: thread_id }
  end

  def redact_for_notification(value)
    text = value.to_s.dup
    text.gsub!(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i, '[email-redacted]')
    text.gsub!(/(password|passwd|pwd|token|secret|otp|2fa|session|key)\s*[:=]\s*\S+/i, '\\1=[REDACTED]')
    text
  end

  def telegram_auth_required_message(context)
    safe_context = redact_for_notification(context)
    [
      '🔐 Release Hub membutuhkan autentikasi App Store Connect',
      "Context: #{safe_context}",
      '',
      'Terminal foreground akan dibuka di Mac ini.',
      'Silakan isi password/2FA hanya di Terminal, jangan kirim password/OTP via Telegram.',
      'Setelah berhasil, proses Release Hub akan retry/lanjut otomatis.'
    ].join("\n")
  end

  def telegram_post_json!(token:, payload:)
    uri = URI("https://api.telegram.org/bot#{token}/sendMessage")
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(payload)

    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: env_int('RELEASE_HUB_TELEGRAM_NOTIFY_OPEN_TIMEOUT', 5, min: 1),
      read_timeout: env_int('RELEASE_HUB_TELEGRAM_NOTIFY_READ_TIMEOUT', 10, min: 1)
    ) do |http|
      http.request(request)
    end
  end

  def notify_telegram_auth_required!(context:)
    return false if telegram_auth_notify_disabled?

    config = telegram_auth_notification_config
    unless present?(config[:token]) && present?(config[:chat_id])
      if env_truthy?('RELEASE_HUB_TELEGRAM_AUTH_NOTIFY_VERBOSE')
        puts 'ℹ️ Notifikasi Telegram auth dilewati: token/chat id belum tersedia.'
      end
      return false
    end

    payload = {
      chat_id: config[:chat_id],
      text: telegram_auth_required_message(context),
      disable_web_page_preview: true
    }
    payload[:message_thread_id] = config[:thread_id] if present?(config[:thread_id])

    response = telegram_post_json!(token: config[:token], payload: payload)
    unless response.is_a?(Net::HTTPSuccess)
      code = response.respond_to?(:code) ? response.code : 'unknown'
      warn "⚠️ Notifikasi Telegram auth gagal dikirim (HTTP #{code})."
      return false
    end

    puts '📨 Notifikasi Telegram auth dikirim.'
    true
  rescue => e
    warn "⚠️ Notifikasi Telegram auth gagal dikirim (#{e.class})."
    false
  end

  def interactive_terminal?
    $stdin.tty? && $stdout.tty?
  end

  def running_on_macos?
    RbConfig::CONFIG['host_os'].to_s.downcase.include?('darwin')
  end

  def applescript_escape(value)
    value.to_s.gsub('\\', '\\\\').gsub('"', '\\"')
  end

  def open_foreground_terminal_auth!(context:, project_root:)
    raise 'Foreground Terminal auth hanya tersedia di macOS.' unless running_on_macos?

    auth_script = File.join(project_root, 'scripts', 'appstore_authenticate.rb')
    raise "Auth helper tidak ditemukan: #{auth_script}" unless File.exist?(auth_script)

    result_file = File.join(
      Dir.tmpdir,
      "release_hub_appstore_auth_#{Process.pid}_#{Time.now.to_i}.json"
    )

    command = [
      "cd #{Shellwords.escape(project_root)}",
      [
        "RELEASE_HUB_AUTH_CONTEXT=#{Shellwords.escape(context.to_s)}",
        "RELEASE_HUB_AUTH_RESULT_FILE=#{Shellwords.escape(result_file)}",
        '/usr/bin/env',
        'ruby',
        Shellwords.escape(auth_script)
      ].join(' ')
    ].join(' && ')

    script = <<~APPLESCRIPT
      tell application "Terminal"
        activate
        set authTab to do script "#{applescript_escape(command)}"
      end tell
      repeat
        delay 1
        tell application "Terminal"
          if not busy of authTab then exit repeat
        end tell
      end repeat
    APPLESCRIPT

    notify_telegram_auth_required!(context: context)
    puts '🪟 Membuka Terminal foreground untuk autentikasi App Store Connect...'
    _stdout, stderr, status = Open3.capture3('osascript', stdin_data: script)
    unless status.success?
      raise "Gagal membuka Terminal auth: #{stderr.strip}"
    end

    unless File.exist?(result_file)
      raise 'Terminal auth ditutup sebelum menghasilkan status. Jalankan ulang proses setelah login selesai.'
    end

    result = JSON.parse(File.read(result_file))
    File.delete(result_file) rescue nil
    return true if result['status'] == 'success'

    raise "Autentikasi App Store Connect gagal di Terminal: #{result['message']}"
  end

  def ensure_authenticated!(context:, project_root:, probe_timeout: nil)
    project_root = File.expand_path(project_root)

    if using_api_key?
      authenticate_with_api_key!(project_root: project_root)
      return :api_key
    end

    raise 'Konfigurasi App Store Connect belum lengkap: isi ASC_ISSUER_ID (API Key) atau APPLE_ID_USERNAME.' unless present?(apple_id)

    puts "🔑 Melakukan otentikasi App Store Connect menggunakan Apple ID (#{apple_id})..."
    begin
      direct_apple_id_login!(timeout_seconds: probe_timeout)
      return :current_process
    rescue Timeout::Error => e
      puts "⚠️ Login App Store Connect butuh interaksi atau terlalu lama: #{e.message}"
      raise if foreground_auth_disabled?
    rescue => e
      raise if foreground_auth_disabled?

      unless auth_error?(e)
        puts "⚠️ Login App Store Connect gagal; mencoba autentikasi foreground: #{e.message}"
      else
        puts "⚠️ Login App Store Connect butuh autentikasi ulang: #{e.message}"
      end
    end

    open_foreground_terminal_auth!(context: context, project_root: project_root)

    puts '🔁 Autentikasi selesai. Mencoba ulang koneksi App Store Connect...'
    direct_apple_id_login!(timeout_seconds: probe_timeout)
    :foreground_terminal
  end

  def with_auth_retry(context:, project_root:, max_attempts: 2)
    project_root = File.expand_path(project_root)
    attempt = 0

    begin
      attempt += 1
      yield
    rescue => e
      raise if using_api_key? || foreground_auth_disabled?
      raise unless auth_error?(e)
      raise if attempt >= max_attempts

      puts "⚠️ Operasi App Store Connect membutuhkan autentikasi ulang: #{e.message}"
      open_foreground_terminal_auth!(context: context, project_root: project_root)
      puts '🔁 Autentikasi selesai. Mengulang operasi sebelumnya...'
      direct_apple_id_login!
      retry
    end
  end

  def run_with_spinner(message)
    worker = Thread.new do
      Thread.current.report_on_exception = false
      yield
    end

    sleep 2
    puts ''

    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0
    start_time = Time.now
    while worker.alive?
      elapsed = (Time.now - start_time).to_i
      mins = elapsed / 60
      secs = elapsed % 60
      print "\r⏳ #{spinner[i % spinner.length]} #{message}... (Waktu berlalu: #{mins}m #{secs}s)   "
      i += 1
      sleep 0.2
    end

    result = worker.value
    puts ''
    result
  end
end
