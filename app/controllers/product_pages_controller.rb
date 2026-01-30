# frozen_string_literal: true

# ProductPagesController manages the product pages being monitored.
# Merchants can:
#   - View monitored pages
#   - Add new pages (up to 5)
#   - Remove pages from monitoring
#   - Trigger manual rescans
#
class ProductPagesController < AuthenticatedController
  include ShopifyApp::EmbeddedApp

  before_action :set_shop
  before_action :set_product_page, only: [:show, :destroy, :rescan]

  def index
    @product_pages = @shop.product_pages.order(created_at: :desc)
    @can_add_more = @shop.can_add_monitored_page?
    @host = params[:host]
  end

  def show
    @recent_scans = @product_page.scans.recent.limit(10)
    @open_issues = @product_page.open_issues.order(severity: :asc, last_detected_at: :desc)
    @host = params[:host]
  end

  def new
    unless @shop.can_add_monitored_page?
      flash[:error] = "You've reached the maximum of #{@shop.shop_setting.max_monitored_pages} monitored pages."
      redirect_to product_pages_path(host: params[:host])
      return
    end

    @products = fetch_products_from_shopify
    @host = params[:host]
  end

  def create
    unless @shop.can_add_monitored_page?
      render json: { error: "Maximum monitored pages reached" }, status: :unprocessable_entity
      return
    end

    # Parse product data from params
    product_id = params[:shopify_product_id].to_i
    handle = params[:handle]
    title = params[:title]

    # Build the PDP URL
    url = "/products/#{handle}"

    @product_page = @shop.product_pages.build(
      shopify_product_id: product_id,
      handle: handle,
      title: title,
      url: url,
      monitoring_enabled: true,
      status: "pending"
    )

    if @product_page.save
      # Queue initial scan
      ScanPdpJob.perform_later(@product_page.id)
      
      flash[:success] = "#{title} added to monitoring. First scan starting now."
      redirect_to product_pages_path(host: params[:host])
    else
      flash[:error] = @product_page.errors.full_messages.join(", ")
      redirect_to new_product_page_path(host: params[:host])
    end
  end

  def destroy
    @product_page.destroy
    flash[:success] = "#{@product_page.title} removed from monitoring."
    redirect_to product_pages_path(host: params[:host])
  end

  def rescan
    if @product_page.scans.running.any?
      flash[:notice] = "A scan is already in progress for this page."
    else
      ScanPdpJob.perform_later(@product_page.id)
      flash[:success] = "Manual scan started for #{@product_page.title}."
    end
    
    redirect_to product_page_path(@product_page, host: params[:host])
  end

  private

  def set_shop
    @shop = Shop.find_by(shopify_domain: current_shopify_domain)
    unless @shop
      redirect_to ShopifyApp.configuration.login_url
    end
  end

  def set_product_page
    @product_page = @shop.product_pages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Product page not found."
    redirect_to product_pages_path(host: params[:host])
  end

  def fetch_products_from_shopify
    # Fetch products from Shopify Admin API
    session = ShopifyAPI::Auth::Session.new(
      shop: @shop.shopify_domain,
      access_token: @shop.shopify_token
    )

    # Get list of product IDs already being monitored
    monitored_ids = @shop.product_pages.pluck(:shopify_product_id)

    begin
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      
      query = <<~GRAPHQL
        query getProducts($first: Int!) {
          products(first: $first, sortKey: TITLE) {
            edges {
              node {
                id
                title
                handle
                status
                featuredImage {
                  url
                }
              }
            }
          }
        }
      GRAPHQL

      response = client.query(query: query, variables: { first: 50 })
      products = response.body.dig("data", "products", "edges") || []
      
      # Filter out already monitored products and return formatted list
      products.map { |edge|
        node = edge["node"]
        gid = node["id"]
        numeric_id = gid.split("/").last.to_i
        
        {
          id: numeric_id,
          title: node["title"],
          handle: node["handle"],
          status: node["status"],
          image_url: node.dig("featuredImage", "url"),
          already_monitored: monitored_ids.include?(numeric_id)
        }
      }
    rescue StandardError => e
      Rails.logger.error("[ProductPagesController] Failed to fetch products: #{e.message}")
      []
    end
  end
end
