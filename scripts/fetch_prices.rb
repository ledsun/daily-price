#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "json"
require "net/http"
require "uri"
require "time"
require "nokogiri"

PRODUCTS_FILE = File.join(__dir__, "..", "products.yaml")
PRICES_FILE = File.join(__dir__, "..", "prices.json")

TIMEOUT = 15
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
ACCEPT_LANGUAGE = "ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7"
SEC_FETCH_DEST = "document"
SEC_FETCH_MODE = "navigate"
SEC_FETCH_SITE = "none"
SEC_FETCH_USER = "?1"
DEBUG_FETCH = ENV["DEBUG_FETCH"] == "1"

def resolve_uri(base_uri, location)
  uri = URI.parse(location)
  return uri unless uri.host.nil?

  if location.start_with?("//")
    return URI.parse("#{base_uri.scheme}:#{location}")
  end

  if location.start_with?("/")
    return URI::Generic.build(
      scheme: base_uri.scheme,
      host: base_uri.host,
      port: base_uri.port,
      path: uri.path,
      query: uri.query,
      fragment: uri.fragment,
    )
  end

  URI.parse(URI.join(base_uri.to_s, location).to_s)
end

def fetch_html(url_str)
  uri = URI.parse(url_str)
  redirects = 0
  loop do
    raise "Too many redirects" if redirects > 5
    raise "Invalid URI host: #{uri}" if uri.host.nil? || uri.host.empty?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept-Language"] = ACCEPT_LANGUAGE
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    request["Sec-Fetch-Dest"] = SEC_FETCH_DEST
    request["Sec-Fetch-Mode"] = SEC_FETCH_MODE
    request["Sec-Fetch-Site"] = SEC_FETCH_SITE
    request["Sec-Fetch-User"] = SEC_FETCH_USER

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      return response.body
    when Net::HTTPRedirection
      location = response["location"]
      raise "Redirect location is missing: #{url_str}" if location.nil? || location.empty?

      uri = resolve_uri(uri, location)
      redirects += 1
    else
      raise "HTTP #{response.code}: #{url_str}"
    end
  end
end

def extract_price(text)
  return nil if text.nil?

  digits = text.gsub(/[^0-9]/, "")
  return nil if digits.empty?

  digits.to_i
end

AMAZON_SELECTORS = [
  "#priceblock_ourprice",
  "#priceblock_dealprice",
  "#priceblock_saleprice",
  ".a-price .a-offscreen",
  "#price_inside_buybox",
  "#newBuyBoxPrice",
  ".apexPriceToPay .a-offscreen",
  "#corePrice_feature_div .a-offscreen",
].freeze

YODOBASHI_SELECTORS = [
  ".priceTxt",
  ".sellingPrice",
  ".js_selling_price",
  ".productPrice",
  "[class*='selling'] [class*='price']",
].freeze

def fetch_amazon_price(url)
  html = fetch_html(url)
  doc = Nokogiri::HTML5.parse(html)

  AMAZON_SELECTORS.each do |selector|
    node = doc.css(selector).first
    next unless node

    price = extract_price(node.text)
    return price if price
  end

  nil
end

def fetch_yodobashi_price(url)
  html = fetch_html(url)
  doc = Nokogiri::HTML5.parse(html)

  YODOBASHI_SELECTORS.each do |selector|
    node = doc.css(selector).first
    next unless node

    price = extract_price(node.text)
    return price if price
  end

  nil
end

products_data = YAML.load_file(PRODUCTS_FILE)
products = products_data["products"] || []

prices = if File.exist?(PRICES_FILE)
           JSON.parse(File.read(PRICES_FILE))
         else
           {}
         end

products.each do |product|
  id = product["id"]
  prices[id] ||= {}

  puts "#{product['name']} を処理中..."

  amazon_url = product["amazon_url"].to_s
  unless amazon_url.empty?
    begin
      price = fetch_amazon_price(amazon_url)
      if price
        prices[id]["amazon"] = {
          "price" => price,
          "fetched_at" => Time.now.iso8601,
        }
        puts "  Amazon: #{price}"
      else
        puts "  Amazon: 価格取得失敗 (前回値を保持)"
      end
    rescue => e
      puts "  Amazon: エラー - #{e.message} (前回値を保持)"
      warn e.full_message if DEBUG_FETCH
    end
  end

  yodobashi_url = product["yodobashi_url"].to_s
  unless yodobashi_url.empty?
    begin
      price = fetch_yodobashi_price(yodobashi_url)
      if price
        prices[id]["yodobashi"] = {
          "price" => price,
          "fetched_at" => Time.now.iso8601,
        }
        puts "  ヨドバシ: #{price}"
      else
        puts "  ヨドバシ: 価格取得失敗 (前回値を保持)"
      end
    rescue => e
      puts "  ヨドバシ: エラー - #{e.message} (前回値を保持)"
      warn e.full_message if DEBUG_FETCH
    end
  end

  sleep 2
end

File.write(PRICES_FILE, JSON.pretty_generate(prices))
puts "prices.json を更新しました。"
