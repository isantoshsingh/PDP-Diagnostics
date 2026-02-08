# frozen_string_literal: true

# HomeController serves the main dashboard (App Home Page)
# per Shopify App Home Page UX guidelines.
#
# The dashboard shows:
#   - PDP health overview
#   - Recent issues
#   - 7-day trend
#   - Quick actions
#
class HomeController < AuthenticatedController
  include ShopifyApp::EmbeddedApp
  include ShopifyApp::EnsureBilling

  def index
    # @shop is already set by AuthenticatedController#set_shop
    if @shop.nil?
      Rails.logger.error("[HomeController] Shop not found for domain: #{current_shopify_domain}")
      redirect_to ShopifyApp.configuration.login_url
      return
    end

    # Preload shop_setting to avoid a separate query in the view
    ActiveRecord::Associations::Preloader.new(records: [@shop], associations: :shop_setting).call

    # Dashboard metrics — single GROUP BY query instead of 4 separate COUNTs
    status_counts = @shop.product_pages.monitoring_enabled.group(:status).count
    @total_pages = status_counts.values.sum
    @healthy_pages = status_counts["healthy"] || 0
    @warning_pages = status_counts["warning"] || 0
    @critical_pages = status_counts["critical"] || 0

    # Open issues — eager load product_page to avoid N+1, .load to avoid extra EXISTS query in view
    open_issues_scope = Issue.joins(:product_page)
                             .where(product_pages: { shop_id: @shop.id })
                             .where(status: "open")
    @open_issues_count = open_issues_scope.count
    @open_issues = open_issues_scope
                     .includes(:product_page)
                     .order(severity: :asc, last_detected_at: :desc)
                     .limit(10)
                     .load

    # Recent scans — eager load product_page to avoid N+1, .load to avoid extra EXISTS query in view
    @recent_scans = Scan.joins(:product_page)
                        .where(product_pages: { shop_id: @shop.id })
                        .includes(:product_page)
                        .order(created_at: :desc)
                        .limit(5)
                        .load

    # 7-day scan history for trend chart
    @scan_history = Scan.joins(:product_page)
                        .where(product_pages: { shop_id: @shop.id })
                        .where("scans.created_at >= ?", 7.days.ago)
                        .group("DATE(scans.created_at)")
                        .count

    @host = params[:host]
  end

  private

  # Override has_active_payment? to implement cache-first logic + sync
  def has_active_payment?(session)
    # Ensure @shop is set (it's set in AuthenticatedController, but just in case)
    @shop ||= Shop.find_by(shopify_domain: session.shop)
    
    # 1. Billing Exempt?
    return true if billing_exempt?

    # 2. Local Cache Active?
    if @shop&.subscription_active?
      Rails.logger.info("[HomeController] Cache hit: Active subscription for #{session.shop}")
      return true
    end

    # 3. Fallback to Shopify API (gem implementation)
    # This query runs against Shopify. If it finds an active subscription:
    api_has_active = super(session)

    if api_has_active
      # 4. Sync local state if API confirms active
      Rails.logger.info("[HomeController] API active, syncing local state for #{session.shop}")
      SubscriptionSyncService.new(@shop).sync
      return true
    end

    # 5. Not active on API -> Gem will redirect
    false
  end
end
