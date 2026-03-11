#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Verify: ProductPageScanner deep scan fix
# =============================================================================
#
# Tests the ACTUAL ProductPageScanner code path with the fix applied.
# Creates a temporary shop + product page, runs a deep scan, and checks
# whether cart.js works correctly (no more deadlock).
#
# Usage:
#   bin/rails runner test/scripts/test_cart_js_fix.rb [URL]
#
# =============================================================================

URL = ARGV[0] || "https://first-shopify-app.myshopify.com/products/organic-cotton-backpack-fair-trade-certified"

puts ""
puts "=" * 70
puts "  ProductPageScanner Deep Scan Fix Verification"
puts "  URL: #{URL}"
puts "  Browser: #{ENV['BROWSERLESS_URL'].present? ? 'Browserless cloud' : 'Local Chrome'}"
puts "  Time: #{Time.current}"
puts "=" * 70
puts ""

shop = nil

begin
  # ── Step 1: Create temporary records ─────────────────────────────────
  print "1. Creating test shop + product page... "
  shop = Shop.create!(
    shopify_domain: "cartfix-test-#{SecureRandom.hex(4)}.myshopify.com",
    shopify_token: "test_token_cartfix",
    billing_exempt: true,
    subscription_status: "active"
  )

  product_page = shop.product_pages.create!(
    shopify_product_id: rand(1_000_000..9_999_999),
    handle: "cart-fix-test-product",
    title: "Cart Fix Test Product",
    url: URL,
    monitoring_enabled: true,
    status: "pending"
  )
  puts "✅"

  # ── Step 2: Run QUICK scan through ProductPageScanner ────────────────
  puts ""
  puts "-" * 70
  puts "  QUICK SCAN (interception ON — structural checks only)"
  puts "-" * 70
  puts ""

  quick_scanner = ProductPageScanner.new(product_page, scan_depth: :quick)
  quick_result = quick_scanner.perform

  if quick_result[:success]
    puts "  ✅ Quick scan completed (#{quick_result[:scan].page_load_time_ms}ms load time)"
    quick_result[:detection_results].each do |r|
      icon = case r[:status]
        when "pass" then "✅"
        when "fail" then "❌"
        when "warning" then "⚠️"
        else "❓"
      end
      name = r[:check].ljust(25)
      puts "     #{icon} #{name} conf=#{format('%.2f', r[:confidence])}  #{r.dig(:details, :message)}"
    end
  else
    puts "  ❌ Quick scan failed: #{quick_result[:error]}"
  end

  # ── Step 3: Run DEEP scan through ProductPageScanner ─────────────────
  puts ""
  puts "-" * 70
  puts "  DEEP SCAN (interception OFF — full funnel test)"
  puts "-" * 70
  puts ""

  deep_scanner = ProductPageScanner.new(product_page, scan_depth: :deep)
  deep_result = deep_scanner.perform

  if deep_result[:success]
    puts "  ✅ Deep scan completed (#{deep_result[:scan].page_load_time_ms}ms load time)"
    deep_result[:detection_results].each do |r|
      icon = case r[:status]
        when "pass" then "✅"
        when "fail" then "❌"
        when "warning" then "⚠️"
        else "❓"
      end
      name = r[:check].ljust(25)
      puts "     #{icon} #{name} conf=#{format('%.2f', r[:confidence])}  #{r.dig(:details, :message)}"

      # Show details for ATC check
      if r[:check] == "add_to_cart"
        tech = r.dig(:details, :technical_details) || {}
        evidence = r.dig(:details, :evidence) || {}
        puts ""
        puts "     Cart Before: #{tech[:cart_before_count]}"
        puts "     Cart After:  #{tech[:cart_after_count]}"
        puts "     Cart Error:  #{tech[:cart_error] || 'none'}"
        puts "     Item Added:  #{evidence[:item_added_to_cart]}"
        puts "     Scan Depth:  #{evidence[:scan_depth]}"
      end
    end
  else
    puts "  ❌ Deep scan failed: #{deep_result[:error]}"
  end

  # ── Summary ──────────────────────────────────────────────────────────
  puts ""
  puts "=" * 70
  puts "  VERIFICATION RESULT"
  puts "=" * 70
  puts ""

  if deep_result[:success]
    atc_result = deep_result[:detection_results].find { |r| r[:check] == "add_to_cart" }
    if atc_result
      cart_error = atc_result.dig(:details, :technical_details, :cart_error)
      item_added = atc_result.dig(:details, :evidence, :item_added_to_cart)
      cart_before = atc_result.dig(:details, :technical_details, :cart_before_count)

      if cart_error.nil? && cart_before.to_i >= 0
        if item_added
          puts "  🎉 FIX VERIFIED — Deep scan works! Cart API readable, item was added."
          puts "     The request interception deadlock is resolved."
        else
          puts "  ⚠️  FIX PARTIALLY VERIFIED — Cart API is readable (no more 'Script returned nil'),"
          puts "     but the item wasn't added to cart. This is likely a product inventory issue,"
          puts "     not a scanner bug."
        end
      elsif cart_error == "Script returned nil"
        puts "  ❌ FIX NOT WORKING — Still getting 'Script returned nil'."
        puts "     The request interception deadlock persists."
      else
        puts "  ⚠️  Cart API returned error: #{cart_error}"
      end
    else
      puts "  ⚠️  No add_to_cart result found in detection results."
    end
  else
    puts "  ❌ Deep scan failed entirely: #{deep_result[:error]}"
  end

  puts ""

rescue StandardError => e
  puts "\n❌ ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
ensure
  if shop
    print "Cleaning up test data... "
    begin
      pp_ids = shop.product_pages.pluck(:id)
      if pp_ids.any?
        ActiveRecord::Base.connection.execute("DELETE FROM alerts WHERE issue_id IN (SELECT id FROM issues WHERE product_page_id IN (#{pp_ids.join(',')}))")
        ActiveRecord::Base.connection.execute("DELETE FROM issues WHERE product_page_id IN (#{pp_ids.join(',')})")
        ActiveRecord::Base.connection.execute("DELETE FROM scans WHERE product_page_id IN (#{pp_ids.join(',')})")
        ActiveRecord::Base.connection.execute("DELETE FROM product_pages WHERE id IN (#{pp_ids.join(',')})")
      end
      ActiveRecord::Base.connection.execute("DELETE FROM shop_settings WHERE shop_id = #{shop.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM shops WHERE id = #{shop.id}")
      puts "done."
    rescue => e
      puts "cleanup warning: #{e.message.lines.first}"
    end
  end
end
