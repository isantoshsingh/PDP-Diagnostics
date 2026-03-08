# frozen_string_literal: true

# AlertMailer sends email notifications to merchants about detected issues.
#
# Emails are designed to be:
#   - Calm and non-alarming (per UX principles)
#   - Clear and actionable
#   - Infrequent (only for confirmed high severity issues)
#   - Include screenshot evidence when available
#   - Include AI-generated plain-language explanations
#
class AlertMailer < ApplicationMailer
  # Sent when one or more high severity issues are detected on a product page.
  # Accepts a list of issues so multiple issues can be batched into a single email.
  def issues_detected(shop, issues)
    @shop = shop
    @issues = Array(issues)
    @product_page = @issues.first.product_page
    @scan = @issues.first.scan
    @app_url = "#{ENV.fetch('HOST', 'https://localhost:3000')}/product_pages/#{@product_page.id}"

    # Attach screenshot inline if available (use first issue's scan screenshot)
    @has_screenshot = false
    if @scan&.screenshot_url.present?
      begin
        screenshot_data = ScreenshotUploader.new.download(@scan.screenshot_url)
        attachments.inline["screenshot.png"] = screenshot_data
        @has_screenshot = true
      rescue StandardError => e
        Rails.logger.warn("[AlertMailer] Failed to attach screenshot: #{e.message}")
      end
    end

    issue_count = @issues.length
    subject = if issue_count == 1
      "Prowl: Issue detected on #{@product_page.title}"
    else
      "Prowl: #{issue_count} issues detected on #{@product_page.title}"
    end

    mail(
      to: shop.shop_setting&.effective_alert_email || shop.email,
      subject: subject
    )
  end

  # Sent when all issues for a page are resolved
  def issues_resolved(shop, product_page)
    @shop = shop
    @product_page = product_page
    @app_url = "#{ENV.fetch('HOST', 'https://localhost:3000')}/product_pages/#{product_page.id}"

    mail(
      to: shop.shop_setting&.effective_alert_email || shop.email,
      subject: "Prowl: #{@product_page.title} is now healthy"
    )
  end
end
