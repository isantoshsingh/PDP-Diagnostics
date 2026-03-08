#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Scan Any Product Page URL — Standalone Diagnostic Script
# =============================================================================
#
# Runs the EXACT production detection pipeline against ANY product page URL
# and logs all results to a timestamped text file for analysis.
#
# Usage:
#   bin/rails runner test/scripts/scan_any_url.rb URL [URL2] [URL3] ...
#
# Examples:
#   bin/rails runner test/scripts/scan_any_url.rb https://allbirds.com/products/mens-tree-runners
#   bin/rails runner test/scripts/scan_any_url.rb https://store1.com/products/a https://store2.com/products/b
#
# Interactive (prompts for URL):
#   bin/rails runner test/scripts/scan_any_url.rb
#
# Output:
#   Results are logged to: tmp/scan_results/scan_<timestamp>.txt
#   Summary is also printed to the console.
#
# What it tests (same as production):
#   1. Add-to-Cart detector (structural + deep funnel test)
#   2. JavaScript Error detector (with noise filtering)
#   3. Liquid Error detector (template rendering issues)
#   4. Price Visibility detector (price element presence)
#   5. Product Image detector (image loading verification)
#   6. Raw browser data: JS errors, console logs, network failures
#   7. DetectionService issue-creation simulation (what would be reported)
#
# =============================================================================

class ScanAnyUrl
  LOG_DIR = Rails.root.join("tmp", "scan_results")

  # ANSI colors for console
  GREEN  = "\e[32m"
  RED    = "\e[31m"
  YELLOW = "\e[33m"
  CYAN   = "\e[36m"
  DIM    = "\e[2m"
  BOLD   = "\e[1m"
  RESET  = "\e[0m"

  STATUS_ICONS = {
    "pass"         => "#{GREEN}✅ PASS#{RESET}",
    "fail"         => "#{RED}❌ FAIL#{RESET}",
    "warning"      => "#{YELLOW}⚠️  WARN#{RESET}",
    "inconclusive" => "#{DIM}❓ INCONCLUSIVE#{RESET}"
  }.freeze

  attr_reader :urls, :log_lines, :log_file

  def initialize(urls)
    @urls = urls
    @log_lines = []
    @all_scan_summaries = []
  end

  def run
    setup_log_file
    print_banner

    urls.each_with_index do |url, idx|
      scan_url(url, idx + 1, urls.length)
    end

    print_grand_summary if urls.length > 1
    flush_log

    puts ""
    puts "#{BOLD}📄 Full report saved to:#{RESET} #{@log_file}"
    puts ""
  end

  private

  # ── Logging ──────────────────────────────────────────────────────────────

  def setup_log_file
    FileUtils.mkdir_p(LOG_DIR)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    @log_file = LOG_DIR.join("scan_#{timestamp}.txt")
  end

  # Prints to console AND appends to the log file buffer
  def log(text = "")
    puts text
    # Strip ANSI codes for the text file
    @log_lines << text.gsub(/\e\[\d+(;\d+)*m/, "")
  end

  def flush_log
    File.write(@log_file, @log_lines.join("\n") + "\n")
  end

  # ── Banner ───────────────────────────────────────────────────────────────

  def print_banner
    log "=" * 78
    log "  Prowl — Product Page Diagnostic Scanner"
    log "  #{urls.length} URL(s) | #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    log "  Log file: #{@log_file}"
    log "=" * 78
    log ""
  end

  # ── Core scan flow ──────────────────────────────────────────────────────

  def scan_url(url, number, total)
    log "-" * 78
    log "  [#{number}/#{total}] #{url}"
    log "-" * 78
    log ""

    scan_start = Time.current
    browser = nil
    summary = { url: url, status: nil, checks: [], issues: [], duration: nil }

    begin
      # 1. Launch browser
      log "  #{CYAN}1. Launching browser...#{RESET}"
      browser = BrowserService.new(block_unnecessary_resources: false)
      browser.start
      log "     #{GREEN}Browser ready#{RESET} (#{ENV['BROWSERLESS_URL'].present? ? 'Browserless cloud' : 'Local Chrome'})"
      log ""

      # 2. Navigate
      log "  #{CYAN}2. Navigating to URL...#{RESET}"
      nav_result = browser.navigate_to(url)

      unless nav_result[:success]
        msg = nav_result[:password_protected] ? "Store is password-protected" : nav_result[:error]
        log "     #{RED}Navigation failed: #{msg}#{RESET}"
        summary[:status] = :nav_failed
        summary[:error] = msg
        log_section_separator
        @all_scan_summaries << summary
        return
      end

      log "     #{GREEN}HTTP #{nav_result[:status_code]}#{RESET} | Load time: #{browser.page_load_time_ms}ms"
      if nav_result[:partial_load]
        log "     #{YELLOW}(Partial load — page didn't fully settle but has content)#{RESET}"
      end
      log ""

      # 3. Capture raw browser data
      log "  #{CYAN}3. Browser-captured data#{RESET}"
      log_browser_data(browser)

      # 4. Run ALL Tier 1 detectors (Quick scan)
      log "  #{CYAN}4. Running Tier 1 detectors (quick scan)#{RESET}"
      log ""
      quick_results = run_all_detectors(browser, scan_depth: :quick)
      log_detector_results(quick_results, summary)

      # 5. Run AddToCartDetector in DEEP mode (full funnel test)
      log "  #{CYAN}5. Running Add-to-Cart deep funnel test#{RESET}"
      log ""

      # Re-navigate for clean state
      browser.navigate_to(url)
      sleep(2)

      deep_atc = Detectors::AddToCartDetector.new(browser, scan_depth: :deep)
      deep_result = deep_atc.perform
      log_single_detector_result("add_to_cart (DEEP)", deep_result, summary)
      log ""

      # 6. Simulate DetectionService issue mapping
      log "  #{CYAN}6. Issue-creation simulation (what Prowl would report)#{RESET}"
      log ""

      # Use the deep ATC result + all other quick results
      combined_results = quick_results.reject { |r| r[:check] == "add_to_cart" } + [deep_result]
      simulate_issue_creation(combined_results, summary)

      # 7. Per-detector deep dive logs
      log "  #{CYAN}7. Detailed detector output#{RESET}"
      log ""
      log_detailed_results(combined_results)

      summary[:status] = summary[:issues].any? { |i| i[:action] == :create_issue } ? :issues_found : :healthy
      summary[:duration] = (Time.current - scan_start).round(2)

    rescue StandardError => e
      log ""
      log "  #{RED}ERROR: #{e.class}: #{e.message}#{RESET}"
      log "  #{DIM}#{e.backtrace.first(5).join("\n  ")}#{RESET}"
      summary[:status] = :error
      summary[:error] = "#{e.class}: #{e.message}"
    ensure
      if browser
        log ""
        log "  #{DIM}Closing browser...#{RESET}"
        browser.close rescue nil
      end
    end

    summary[:duration] ||= (Time.current - scan_start).round(2)
    @all_scan_summaries << summary

    # Per-URL summary
    log ""
    log_url_summary(summary)
    log ""
  end

  # ── Detector execution ─────────────────────────────────────────────────

  def run_all_detectors(browser, scan_depth: :quick)
    results = []

    ProductPageScanner::TIER1_DETECTORS.each do |detector_class|
      begin
        detector = if detector_class == Detectors::AddToCartDetector
          detector_class.new(browser, scan_depth: scan_depth)
        else
          detector_class.new(browser)
        end
        result = detector.perform
        results << result if result
      rescue StandardError => e
        log "     #{RED}#{detector_class.name} crashed: #{e.message}#{RESET}"
        results << {
          check: detector_class.name.demodulize.underscore.sub("_detector", ""),
          status: "inconclusive",
          confidence: 0.0,
          details: { message: "Detector crashed: #{e.message}", technical_details: {}, suggestions: [], evidence: {} }
        }
      end
    end

    results
  end

  # ── Logging helpers ────────────────────────────────────────────────────

  def log_browser_data(browser)
    js_err_count = browser.js_errors.length
    console_err_count = browser.console_logs.count { |l| l[:type] == "error" }
    net_err_count = browser.critical_network_errors.length
    total_console = browser.console_logs.length

    log "     Page load time:    #{browser.page_load_time_ms}ms"
    log "     JS errors:         #{js_err_count}#{js_err_count > 0 ? " #{YELLOW}⚠#{RESET}" : ""}"
    log "     Console errors:    #{console_err_count} (of #{total_console} total console messages)"
    log "     Network errors:    #{net_err_count} (critical only, noise filtered)"
    log ""

    if browser.js_errors.any?
      log "     #{BOLD}Raw JS errors:#{RESET}"
      browser.js_errors.first(5).each_with_index do |err, i|
        msg = err[:message].to_s.lines.first&.strip || "(empty)"
        log "       [#{i + 1}] #{msg.truncate(120)}"
      end
      log "       ... and #{browser.js_errors.length - 5} more" if browser.js_errors.length > 5
      log ""
    end

    if browser.critical_network_errors.any?
      log "     #{BOLD}Critical network failures:#{RESET}"
      browser.critical_network_errors.first(5).each_with_index do |err, i|
        log "       [#{i + 1}] #{err[:resource_type]} #{err[:failure]} — #{err[:url].to_s.truncate(100)}"
      end
      log ""
    end
  end

  def log_detector_results(results, summary)
    results.each do |result|
      log_single_detector_result(result[:check], result, summary)
    end
    log ""
  end

  def log_single_detector_result(label, result, summary)
    status = result[:status]
    confidence = result[:confidence]
    message = result.dig(:details, :message)
    icon = STATUS_ICONS[status] || status

    name_col = label.ljust(25)
    conf_col = "conf=#{format('%.2f', confidence)}"

    log "     #{icon}  #{name_col} #{conf_col}  #{message}"

    summary[:checks] << { check: label, status: status, confidence: confidence, message: message }
  end

  def log_detailed_results(results)
    results.each do |result|
      check = result[:check]
      details = result[:details] || {}
      tech = details[:technical_details] || {}
      evidence = details[:evidence] || {}
      suggestions = details[:suggestions] || []

      log "     ┌─ #{BOLD}#{check}#{RESET}"
      log "     │  Status:     #{result[:status]}"
      log "     │  Confidence: #{result[:confidence]}"
      log "     │  Message:    #{details[:message]}"

      if tech.any?
        log "     │  Technical:"
        tech.each do |k, v|
          val = v.is_a?(Array) ? v.first(3).map { |e| e.to_s.truncate(100) }.join("; ") + (v.length > 3 ? " (+#{v.length - 3} more)" : "") : v.to_s.truncate(200)
          log "     │    #{k}: #{val}"
        end
      end

      if evidence.any?
        log "     │  Evidence:"
        evidence.each do |k, v|
          log "     │    #{k}: #{v}"
        end
      end

      if suggestions.any?
        log "     │  Suggestions:"
        suggestions.each { |s| log "     │    • #{s}" }
      end

      log "     └─"
      log ""
    end
  end

  def simulate_issue_creation(results, summary)
    any_action = false

    results.each do |result|
      check = result[:check] || result["check"]
      status = result[:status] || result["status"]
      confidence = (result[:confidence] || result["confidence"]).to_f

      issue_type = DetectionService::CHECK_TO_ISSUE_TYPE[check]
      severity = DetectionService::CHECK_SEVERITY[check]
      next unless issue_type

      threshold = DetectionService::CONFIDENCE_THRESHOLD
      would_create = status == "fail" && confidence >= threshold
      would_warn = status == "warning" && confidence >= threshold
      would_resolve = status == "pass"

      if would_create
        title = Issue::ISSUE_TYPES.dig(issue_type, :title) || result.dig(:details, :message)
        icon = severity == "high" ? "🔴" : "🟠"
        log "     #{icon} CREATE ISSUE [#{severity&.upcase}] #{issue_type}"
        log "        Title: #{title}"
        log "        Confidence: #{confidence}"
        summary[:issues] << { issue_type: issue_type, severity: severity, action: :create_issue, confidence: confidence }
        any_action = true
      elsif would_warn
        log "     🟡 CREATE WARNING [low] #{issue_type}"
        log "        Confidence: #{confidence}"
        summary[:issues] << { issue_type: issue_type, severity: "low", action: :create_warning, confidence: confidence }
        any_action = true
      elsif would_resolve
        log "     #{GREEN}🟢 RESOLVE#{RESET} #{issue_type} (check passed)"
        any_action = true
      else
        log "     #{DIM}⚪ NO ACTION#{RESET} #{issue_type} (conf=#{confidence} < #{threshold})"
      end
    end

    unless any_action
      log "     #{DIM}No actions would be taken.#{RESET}"
    end

    log ""
  end

  def log_url_summary(summary)
    log "  ┌────────────────────────────────────────────────────────────────────┐"

    status_text = case summary[:status]
    when :healthy
      "#{GREEN}✅ HEALTHY — No issues would be reported#{RESET}"
    when :issues_found
      issue_count = summary[:issues].count { |i| i[:action] == :create_issue }
      high_count = summary[:issues].count { |i| i[:action] == :create_issue && i[:severity] == "high" }
      "#{RED}❌ #{issue_count} ISSUE(S) DETECTED#{RESET} (#{high_count} high severity)"
    when :nav_failed
      "#{RED}🚫 NAVIGATION FAILED: #{summary[:error]}#{RESET}"
    when :error
      "#{RED}💥 ERROR: #{summary[:error].to_s.truncate(60)}#{RESET}"
    else
      "#{DIM}Unknown status#{RESET}"
    end

    log "  │  #{status_text}"

    if summary[:issues].any? { |i| i[:action] == :create_issue }
      log "  │"
      summary[:issues].select { |i| i[:action] == :create_issue }.each do |issue|
        sev_color = issue[:severity] == "high" ? RED : YELLOW
        log "  │  #{sev_color}[#{issue[:severity].upcase}]#{RESET} #{issue[:issue_type]} (conf=#{issue[:confidence]})"
      end
    end

    checks_passed = summary[:checks].count { |c| c[:status] == "pass" }
    checks_total = summary[:checks].length
    log "  │"
    log "  │  Checks: #{checks_passed}/#{checks_total} passed | Duration: #{summary[:duration]}s"
    log "  └────────────────────────────────────────────────────────────────────┘"
  end

  def log_section_separator
    log ""
    log "  " + "─" * 74
    log ""
  end

  # ── Grand summary (multiple URLs) ──────────────────────────────────────

  def print_grand_summary
    log ""
    log "=" * 78
    log "  GRAND SUMMARY — #{@all_scan_summaries.length} URLs scanned"
    log "=" * 78
    log ""

    healthy = @all_scan_summaries.count { |s| s[:status] == :healthy }
    with_issues = @all_scan_summaries.count { |s| s[:status] == :issues_found }
    failed = @all_scan_summaries.count { |s| s[:status] == :nav_failed }
    errored = @all_scan_summaries.count { |s| s[:status] == :error }

    @all_scan_summaries.each_with_index do |s, i|
      icon = case s[:status]
      when :healthy      then "#{GREEN}✅#{RESET}"
      when :issues_found then "#{RED}❌#{RESET}"
      when :nav_failed   then "#{RED}🚫#{RESET}"
      when :error        then "#{RED}💥#{RESET}"
      else "❓"
      end

      issue_summary = if s[:issues].any? { |i| i[:action] == :create_issue }
        types = s[:issues].select { |i| i[:action] == :create_issue }.map { |i| i[:issue_type] }.join(", ")
        " → #{types}"
      else
        ""
      end

      duration = s[:duration] ? " (#{s[:duration]}s)" : ""
      log "  #{icon} [#{i + 1}] #{s[:url].truncate(60)}#{duration}#{issue_summary}"
    end

    log ""
    log "  #{GREEN}Healthy: #{healthy}#{RESET} | #{RED}Issues: #{with_issues}#{RESET} | " \
        "#{RED}Nav failed: #{failed}#{RESET} | #{RED}Errors: #{errored}#{RESET}"
    log ""

    # Aggregate all unique issue types found across all URLs
    all_issue_types = @all_scan_summaries
      .flat_map { |s| s[:issues].select { |i| i[:action] == :create_issue }.map { |i| i[:issue_type] } }
      .tally

    if all_issue_types.any?
      log "  #{BOLD}Issue frequency across all scans:#{RESET}"
      all_issue_types.sort_by { |_, count| -count }.each do |type, count|
        log "    #{type}: #{count} occurrence(s)"
      end
      log ""
    end
  end
end

# =============================================================================
# Entry point
# =============================================================================

urls = ARGV.dup

if urls.empty?
  puts ""
  puts "  Prowl — Product Page Diagnostic Scanner"
  puts "  Enter product page URL(s) to scan (one per line, blank line to start):"
  puts ""

  loop do
    print "  URL: "
    input = $stdin.gets&.strip
    break if input.nil? || input.empty?
    urls << input
  end

  if urls.empty?
    puts "  No URLs provided. Exiting."
    exit 0
  end
end

# Validate URLs
urls.each do |url|
  unless url.match?(%r{\Ahttps?://}i)
    puts "  ❌ Invalid URL: #{url}"
    puts "     URLs must start with http:// or https://"
    exit 1
  end
end

ScanAnyUrl.new(urls).run
