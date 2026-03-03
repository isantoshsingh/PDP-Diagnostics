# frozen_string_literal: true

module ScreenshotsHelper
  # Generates a signed screenshot URL that can be used in <img> tags.
  # The token encodes the scan_id so ScreenshotsController can verify
  # the request without requiring a full Shopify session (which <img>
  # tags cannot provide).
  def signed_screenshot_path(scan_id)
    token = Rails.application.message_verifier(:screenshots).generate(
      { scan_id: scan_id },
      expires_in: 24.hours
    )
    screenshot_path(scan_id, token: token)
  end
end
