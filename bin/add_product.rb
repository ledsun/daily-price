#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "uri"
require "cgi"

PRODUCTS_FILE = File.join(__dir__, "..", "products.yaml")

def slugify(name)
  slug = name.downcase
  slug = slug.gsub(/[^a-z0-9]+/, "_")
  slug = slug.gsub(/^_+|_+$/, "")
  slug = slug.gsub(/_+/, "_")
  return slug unless slug.empty?

  "product_#{name.encode("UTF-8").unpack1("H*")}"
end

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

if amazon_url.empty? && yodobashi_url.empty?
  puts "エラー: Amazon URLとヨドバシURLのどちらか一方は必須です。"
  exit 1
end

products = load_products
id = slugify(name)

if id.empty?
  puts "エラー: 商品名から有効なIDを生成できませんでした。"
  exit 1
end

if products.any? { |p| p["id"] == id }
  puts "エラー: ID '#{id}' は既に存在します。"
  exit 1
end

product = { "id" => id, "name" => name }
product["amazon_url"] = amazon_url unless amazon_url.empty?
product["yodobashi_url"] = yodobashi_url unless yodobashi_url.empty?

products << product
save_products(products)

puts ""
puts "商品を追加しました: #{id}"
