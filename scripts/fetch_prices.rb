#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "json"
require "net/http"
require "uri"
require "time"
require "gammo"

PRODUCTS_FILE = File.join(__dir__, "..", "products.yaml")
PRICES_FILE = File.join(__dir__, "..", "prices.json")

TIMEOUT = 15
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
ACCEPT_LANGUAGE = "ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7"

def fetch_html(url_str)
  uri = URI.parse(url_str)
  redirects = 0
  loop do
    raise "Too many redirects" if redirects > 5

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept-Language"] = ACCEPT_LANGUAGE
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      return response.body
    when Net::HTTPRedirection
      uri = URI.parse(response["location"])
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
  doc = Gammo.new(html).parse

  AMAZON_SELECTORS.each do |selector|
    node = doc.css(selector).first
    next unless node

    price = extract_price(node.inner_text)
    return price if price
  end

  nil
end

def fetch_yodobashi_price(url)
  html = fetch_html(url)
  doc = Gammo.new(html).parse

  YODOBASHI_SELECTORS.each do |selector|
    node = doc.css(selector).first
    next unless node

    price = extract_price(node.inner_text)
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
    end
  end

  sleep 2
end

File.write(PRICES_FILE, JSON.pretty_generate(prices))
puts "prices.json を更新しました。"
