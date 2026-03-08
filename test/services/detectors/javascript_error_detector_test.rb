# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Tests for Detectors::JavascriptErrorDetector
#
# Covers:
#   1. WPM / shopifycloud analytics errors are ignored (false-positive fix)
#   2. Real purchase-critical errors are still caught
#   3. Third-party noise (GA, FB pixel, etc.) is ignored
#   4. Clean pages get a PASS with high confidence
#   5. Non-critical errors produce a WARNING, not a FAIL
#   6. Confidence scoring tiers (0.95 / 0.85 / 0.80)
# =============================================================================
class JavascriptErrorDetectorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds a minimal browser_service double with controllable js_errors /
  # console_logs so we never need a real browser.
  def browser_service_for(js_errors: [], console_logs: [])
    stub = Object.new
    stub.define_singleton_method(:js_errors)    { js_errors }
    stub.define_singleton_method(:console_logs) { console_logs }
    stub
  end

  def build_detector(js_errors: [], console_logs: [])
    bs = browser_service_for(js_errors: js_errors, console_logs: console_logs)
    Detectors::JavascriptErrorDetector.new(bs)
  end

  # The exact WPM error captured from the production scan
  WPM_STACK_TRACE = <<~MSG.strip
    TypeError: Failed to fetch
        at https://first-shopify-app.myshopify.com/cdn/wpm/bbf9845e7wa149a8fap8725b901m2e609aaem.js:1:68123
        at window2.fetch (https://first-shopify-app.myshopify.com/cdn/shopifycloud/storefront/assets/shop_events_listener-3da45d37.js:1:7564)
        at cn.exportTo (https://cdn.shopify.com/shopifycloud/shop-js/modules/v2/chunk.common_rbA8TQx3.esm.js:1:71721)
        at cn.exportBatches (https://cdn.shopify.com/shopifycloud/shop-js/modules/v2/chunk.common_rbA8TQx3.esm.js:1:72559)
        at cn.exportMetrics (https://cdn.shopify.com/shopifycloud/shop-js/modules/v2/chunk.common_rbA8TQx3.esm.js:1:70920)
  MSG

  # ---------------------------------------------------------------------------
  # Suite 1 — WPM False-Positive Fix (core regression tests)
  # ---------------------------------------------------------------------------

  test "WPM error from /cdn/wpm/ is ignored — no false positive" do
    detector = build_detector(
      js_errors: [{ message: WPM_STACK_TRACE }]
    )

    result = detector.perform

    assert_equal "pass", result[:status],
      "Expected PASS but got #{result[:status].upcase}: #{result.dig(:details, :message)}"
    assert_equal "No critical JavaScript errors detected", result.dig(:details, :message)
  end

  test "WPM error reported twice still produces a PASS" do
    detector = build_detector(
      js_errors: [
        { message: WPM_STACK_TRACE },
        { message: WPM_STACK_TRACE }
      ]
    )

    result = detector.perform
    assert_equal "pass", result[:status]
  end

  test "shopifycloud/shop-js error is noise and does not trigger FAIL" do
    msg = "TypeError: Failed to fetch\n    at https://cdn.shopify.com/shopifycloud/shop-js/modules/v2/chunk.esm.js:1:100"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "pass", result[:status]
  end

  test "shop_events_listener error is noise and does not trigger FAIL" do
    msg = "TypeError: NetworkError\n    at https://example.myshopify.com/cdn/shopifycloud/storefront/assets/shop_events_listener-abc123.js:1:500"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "pass", result[:status]
  end

  test "shopifycloud/storefront error is noise and does not trigger FAIL" do
    msg = "Error: net::ERR_FAILED\n    at https://mystore.myshopify.com/cdn/shopifycloud/storefront/assets/theme-a1b2c3.js:1:999"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "pass", result[:status]
  end

  test "confidence is NOT 0.95 for WPM error (was the false-positive signature)" do
    detector = build_detector(js_errors: [{ message: WPM_STACK_TRACE }])
    result = detector.perform
    refute_equal 0.95, result[:confidence],
      "Confidence should not be 0.95 — that was the false-positive signature"
  end

  # ---------------------------------------------------------------------------
  # Suite 2 — Real Errors Should Still Be Caught
  # ---------------------------------------------------------------------------

  test "real TypeError in theme cart.js triggers FAIL" do
    msg = "TypeError: Cannot read properties of null (reading 'addEventListener')\n    at https://mystore.myshopify.com/cdn/shop/t/5/assets/theme.js:1:4500"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "fail", result[:status]
    assert_match "critical JavaScript error", result.dig(:details, :message)
  end

  test "cart-related TypeError gives FAIL with 0.95 confidence" do
    msg = "TypeError: cart.add is not a function\n    at theme.js:50"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "fail", result[:status]
    assert_equal 0.95, result[:confidence],
      "Expected max confidence 0.95 for combined critical+syntax match"
  end

  test "checkout JS error triggers FAIL" do
    msg = "ReferenceError: checkoutForm is not defined\n    at checkout.js:10"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "fail", result[:status]
  end

  test "product variant error triggers FAIL" do
    msg = "TypeError: Cannot set property 'variant' of undefined\n    at product.js:22"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "fail", result[:status]
  end

  test "critical_errors count in evidence is correct for real errors" do
    msg = "TypeError: cart.add is not defined\n    at theme.js:1"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    evidence = result.dig(:details, :evidence)
    assert evidence[:critical_count] >= 1
  end

  # ---------------------------------------------------------------------------
  # Suite 3 — Third-Party Noise Is Ignored
  # ---------------------------------------------------------------------------

  {
    "Google Analytics"    => "TypeError: ga is not defined\n    at googletagmanager.js:1",
    "Facebook Pixel"      => "Error at fbevents.js: Failed to fetch",
    "Hotjar"              => "TypeError: Cannot read property at hotjar.js:1",
    "TikTok Pixel"        => "Error from tiktok analytics script",
    "Klaviyo"             => "TypeError: klaviyo is not defined\n    at klaviyo.js:1",
    "Google GTM"          => "Error in gtm.js tracker",
    "Privy popup"         => "TypeError: privy popup failed to load"
  }.each do |vendor, error_message|
    test "#{vendor} error is ignored and does not trigger FAIL" do
      detector = build_detector(js_errors: [{ message: error_message }])
      result = detector.perform
      assert_equal "pass", result[:status],
        "#{vendor} error should be ignored but got #{result[:status]}: #{result.dig(:details, :message)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Suite 4 — Clean Page
  # ---------------------------------------------------------------------------

  test "no errors returns PASS with confidence 0.9" do
    detector = build_detector(js_errors: [], console_logs: [])
    result = detector.perform

    assert_equal "pass", result[:status]
    assert_equal 0.9, result[:confidence]
    assert_equal "No critical JavaScript errors detected", result.dig(:details, :message)
  end

  test "pass result evidence shows zero filtered errors" do
    detector = build_detector(js_errors: [], console_logs: [])
    result = detector.perform

    assert_equal 0, result.dig(:details, :evidence, :filtered_count)
  end

  # ---------------------------------------------------------------------------
  # Suite 5 — Non-Critical Errors Become Warnings, Not Failures
  # ---------------------------------------------------------------------------

  test "unrelated JS error produces WARNING not FAIL" do
    msg = "Error: An unknown script crashed\n    at some-widget.js:1"
    detector = build_detector(js_errors: [{ message: msg }])

    result = detector.perform
    assert_equal "warning", result[:status],
      "Non-critical error should be a warning but got #{result[:status]}"
  end

  test "warning result has lower confidence than fail result" do
    warning_msg = "Error: widget failed\n    at widget.js:1"
    critical_msg = "TypeError: cart.add is not a function\n    at theme.js:1"

    warn_result = build_detector(js_errors: [{ message: warning_msg }]).perform
    fail_result = build_detector(js_errors: [{ message: critical_msg }]).perform

    assert warn_result[:confidence] < fail_result[:confidence],
      "Warning confidence (#{warn_result[:confidence]}) should be less than fail confidence (#{fail_result[:confidence]})"
  end

  # ---------------------------------------------------------------------------
  # Suite 6 — Console Log Errors Are Also Analyzed
  # ---------------------------------------------------------------------------

  test "console error type is included in analysis" do
    console_log = { type: "error", text: "TypeError: cart.items is null\n    at theme.js:1" }
    detector = build_detector(js_errors: [], console_logs: [console_log])

    result = detector.perform
    assert_equal "fail", result[:status],
      "Console errors of type 'error' should be analyzed"
  end

  test "console log type 'log' is not analyzed as an error" do
    console_log = { type: "log", text: "TypeError: would be critical if analyzed" }
    detector = build_detector(js_errors: [], console_logs: [console_log])

    result = detector.perform
    # type == 'log' should NOT be treated as an error
    assert_equal "pass", result[:status]
  end

  # ---------------------------------------------------------------------------
  # Suite 7 — Confidence Scoring Tiers
  # ---------------------------------------------------------------------------

  test "confidence is 0.95 when both critical and syntax patterns match" do
    # cart (critical) + TypeError (syntax) = 0.95
    msg = "TypeError: cart.add is not a function\n    at theme.js:1"
    result = build_detector(js_errors: [{ message: msg }]).perform
    assert_equal 0.95, result[:confidence]
  end

  test "confidence is 0.85 when only critical pattern matches (no TypeError/SyntaxError prefix)" do
    # checkout (critical) — but not matching a SYNTAX_ERROR_PATTERN prefix
    msg = "Error: checkout step failed\n    at app.js:1"
    result = build_detector(js_errors: [{ message: msg }]).perform
    # critical-only = 0.85 (assuming it doesn't hit syntax patterns)
    assert_equal 0.85, result[:confidence]
  end

  test "confidence is 0.80 when only syntax pattern matches" do
    # SyntaxError with no cart/checkout/product context
    msg = "SyntaxError: Unexpected token '<'\n    at eval:1"
    result = build_detector(js_errors: [{ message: msg }]).perform
    assert_equal 0.80, result[:confidence]
  end

  # ---------------------------------------------------------------------------
  # Suite 8 — IGNORE_PATTERNS constant is defined and frozen
  # ---------------------------------------------------------------------------

  test "IGNORE_PATTERNS is defined and frozen" do
    assert_not_nil  Detectors::JavascriptErrorDetector::IGNORE_PATTERNS
    assert          Detectors::JavascriptErrorDetector::IGNORE_PATTERNS.frozen?
  end

  test "IGNORE_PATTERNS includes all four newly added Shopify CDN entries" do
    # Regexp#source returns the raw pattern string without escape processing,
    # e.g. /\/cdn\/wpm\//i.source => "/cdn/wpm/"
    patterns = Detectors::JavascriptErrorDetector::IGNORE_PATTERNS.map(&:source)

    assert_includes patterns, '/cdn/wpm/',              "Missing WPM pattern"
    assert_includes patterns, 'shopifycloud/shop-js',   "Missing shop-js pattern"
    assert_includes patterns, 'shop_events_listener',   "Missing shop_events_listener pattern"
    assert_includes patterns, 'shopifycloud/storefront', "Missing shopifycloud/storefront pattern"
  end
end
