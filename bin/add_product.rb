#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "uri"
require "cgi"
require "securerandom"

PRODUCTS_FILE = File.join(__dir__, "..", "products.yaml")

def load_products
  data = YAML.load_file(PRODUCTS_FILE)
  data["products"] || []
end

def save_products(products)
  File.write(PRODUCTS_FILE, YAML.dump({ "products" => products }))
end

def amazon_search_url(name)
  "https://www.amazon.co.jp/s?k=#{CGI.escape(name)}"
end

def yodobashi_search_url(name)
  "https://www.yodobashi.com/?word=#{CGI.escape(name)}"
end

def normalize_amazon_url(url)
  return url if url.empty?

  uri = URI.parse(url)
  asin = uri.path.match(%r{/(?:dp|gp/product|gp/aw/d)/([A-Z0-9]{10})(?:/|$)})&.captures&.first
  return url unless asin

  "https://www.amazon.co.jp/dp/#{asin}"
rescue URI::InvalidURIError
  url
end

def prompt(message)
  print message
  $stdout.flush
  gets.to_s.strip
end

name = prompt("商品名を入力してください: ")
if name.empty?
  puts "エラー: 商品名を入力してください。"
  exit 1
end

puts ""
puts "以下のURLで検索してください:"
puts "  Amazon:    #{amazon_search_url(name)}"
puts "  ヨドバシ:  #{yodobashi_search_url(name)}"
puts ""

amazon_url = prompt("Amazon の商品ページURL (不要なら空Enter): ")
yodobashi_url = prompt("ヨドバシの商品ページURL (不要なら空Enter): ")
amazon_url = normalize_amazon_url(amazon_url)

if amazon_url.empty? && yodobashi_url.empty?
  puts "エラー: Amazon URLとヨドバシURLのどちらか一方は必須です。"
  exit 1
end

products = load_products

product = {
  "id" => SecureRandom.uuid,
  "name" => name,
}
product["amazon_url"] = amazon_url unless amazon_url.empty?
product["yodobashi_url"] = yodobashi_url unless yodobashi_url.empty?

products << product
save_products(products)

puts ""
puts "商品を追加しました: #{name}"
