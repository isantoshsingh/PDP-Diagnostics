# frozen_string_literal: true

# EmailActionsController handles actions triggered from alert emails.
# These endpoints are PUBLIC (no Shopify auth required) and use
# Rails signed_id tokens for secure, expiring authentication.
#
# This allows merchants to acknowledge issues directly from their
# email without having to log into the Shopify app.
#
class EmailActionsController < ApplicationController
  # No Shopify auth, no app layout — standalone public pages secured by signed tokens
  layout false
  skip_before_action :verify_authenticity_token, only: [:acknowledge_issue]

  # GET/POST /email_actions/acknowledge/:signed_id
  def acknowledge_issue
    @issue = Issue.find_signed(params[:signed_id], purpose: :acknowledge)

    if @issue.nil?
      @error = "This link has expired or is invalid. Please acknowledge the issue from the Prowl app."
      render :acknowledge_result, status: :not_found and return
    end

    if @issue.status == "acknowledged"
      @already_acknowledged = true
      @issue_title = @issue.title
      @product_title = @issue.product_page.title
      render :acknowledge_result and return
    end

    @issue.acknowledge!(by: "email")
    @issue_title = @issue.title
    @product_title = @issue.product_page.title
    @acknowledged = true
    render :acknowledge_result
  end
end
