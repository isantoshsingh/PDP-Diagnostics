# frozen_string_literal: true

class AuthenticatedController < ApplicationController
  include ShopifyApp::EnsureHasSession
  before_action :set_shop
  before_action :set_host

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
  # Reuses @shop set by set_shop (which runs before billing checks)
  def billing_exempt?
    @shop&.billing_exempt? || false
  end
end
