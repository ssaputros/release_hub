require 'spaceship'
Spaceship::ConnectAPI.login(ENV["APPLE_ID_USERNAME"])
app = Spaceship::ConnectAPI::App.find("com.hashmicro.inventory.uitc")
puts app.get_edit_app_store_version.app_store_version_localizations.map(&:locale).join(", ")
