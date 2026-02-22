# frozen_string_literal: true

# Puppeteer configuration for headless browser scanning.
#
# On Heroku, Google Chrome is installed via the heroku-buildpack-google-chrome
# buildpack, which sets GOOGLE_CHROME_BIN to the Chrome binary path.
# We store this as a global config so PdpScannerService can use it.
#
# Set PUPPETEER_EXECUTABLE_PATH to override the Chrome binary path explicitly.
# If neither env var is set, puppeteer-ruby falls back to its bundled Chromium.

Rails.application.config.puppeteer = ActiveSupport::OrderedOptions.new
Rails.application.config.puppeteer.executable_path =
  ENV["PUPPETEER_EXECUTABLE_PATH"].presence ||
  ENV["GOOGLE_CHROME_BIN"].presence
