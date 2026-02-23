# frozen_string_literal: true

# ComplianceController handles the GDPR webhooks from Shopify.
#
class Webhooks::ComplianceController < ApplicationController
  include ShopifyApp::WebhookVerification

  def customers_data_request
    # Handle customer data request
    head :ok
  end

  def customers_redact
    # Handle customer data redaction
    head :ok
  end

  def shop_redact
    # Handle shop data redaction
    head :ok
  end
end