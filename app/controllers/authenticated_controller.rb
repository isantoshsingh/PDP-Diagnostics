# frozen_string_literal: true

class AuthenticatedController < ApplicationController
  include ShopifyApp::EnsureHasSession
  before_action :set_shop
  before_action :set_host

  # Override has_active_payment? to implement cache-first logic + sync
  def has_active_payment?(session)
    # Use @shop from set_shop callback if available, otherwise load it
    # This prevents duplicate Shop queries across the request lifecycle
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

  private

  # Set @shop for use across controllers
  def set_shop
    @shop = Shop.find_by(shopify_domain: current_shopify_session&.shop) if current_shopify_session
  end

  # Set @host for use in views (needed for navigation links)
  def set_host
    @host = params[:host]
  end

  # Check if current shop is exempt from billing
  # Uses @shop from set_shop callback, with fallback to direct load if needed
  def billing_exempt?
    return false unless current_shopify_session

    # Use @shop if already loaded, otherwise load it (and cache for later use)
    @shop ||= Shop.find_by(shopify_domain: current_shopify_session.shop)
    @shop&.billing_exempt? || false
  end
end
