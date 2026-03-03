# frozen_string_literal: true

# ScreenshotsController serves scan screenshots.
# Downloads from R2 (production) or local tmp/ (development) and streams to browser.
# Screenshots are private — served through this controller, never publicly accessible.
#
# Authorization: Uses signed URLs (MessageVerifier) instead of Shopify session auth.
# <img> tags make plain GET requests that cannot carry Shopify JWT tokens, so we
# sign the URL at render time and verify the signature here. The token expires
# after 24 hours and is tied to a specific scan_id.
#
class ScreenshotsController < ApplicationController
  def show
    # Verify the signed token — prevents unauthorized access without Shopify session
    verified = Rails.application.message_verifier(:screenshots).verified(params[:token])
    unless verified.is_a?(Hash) && verified[:scan_id] == params[:scan_id].to_i
      head :unauthorized
      return
    end

    scan = Scan.find_by(id: params[:scan_id])

    unless scan&.screenshot_url.present?
      head :not_found
      return
    end

    begin
      screenshot_data = ScreenshotUploader.new.download(scan.screenshot_url)
      send_data screenshot_data,
        type: "image/png",
        disposition: "inline",
        filename: "scan_#{scan.id}.png"
    rescue ScreenshotUploader::UploadError => e
      Rails.logger.warn("[ScreenshotsController] Screenshot not found: #{e.message}")
      head :not_found
    rescue StandardError => e
      Rails.logger.error("[ScreenshotsController] Error serving screenshot: #{e.message}")
      head :internal_server_error
    end
  end
end
