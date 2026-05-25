require 'dotenv'
require 'spaceship'

Dotenv.load('.env')
key_id = ENV['ASC_KEY_ID']
issuer_id = ENV['ASC_ISSUER_ID']
key_filepath = ENV['ASC_KEY_FILE']

token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_filepath
)
Spaceship::ConnectAPI.token = token

app = Spaceship::ConnectAPI::App.find("com.example.smkgemanusantara") # We need a real app identifier. Let's get one from projects.json
if app
  builds1 = app.get_builds(sort: "-uploadedDate", limit: 1)
  puts "Without filter: #{builds1.map(&:version)}"

  builds2 = app.get_builds(filter: { processingState: "PROCESSING,FAILED,VALID,INVALID" }, sort: "-uploadedDate", limit: 1)
  puts "With filter: #{builds2.map(&:version)}"
end
