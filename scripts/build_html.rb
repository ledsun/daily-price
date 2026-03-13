#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "json"
require "erb"
require "time"

PRODUCTS_FILE = File.join(__dir__, "..", "products.yaml")
PRICES_FILE = File.join(__dir__, "..", "prices.json")
OUTPUT_FILE = File.join(__dir__, "..", "web", "index.html")

def format_price(price)
  return "-" if price.nil?

  price.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def format_time(fetched_at)
  return "-" if fetched_at.nil?

  Time.parse(fetched_at).strftime("%Y-%m-%d %H:%M")
rescue ArgumentError
  "-"
end

products_data = YAML.load_file(PRODUCTS_FILE)
products = products_data["products"] || []

prices = if File.exist?(PRICES_FILE)
           JSON.parse(File.read(PRICES_FILE))
         else
           {}
         end

generated_at = Time.now.strftime("%Y-%m-%d %H:%M")

template = <<~HTML
  <!DOCTYPE html>
  <html lang="ja">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>日用品価格比較</title>
    <style>
      body {
        font-family: sans-serif;
        max-width: 960px;
        margin: 0 auto;
        padding: 1rem;
        color: #333;
      }
      h1 { font-size: 1.4rem; margin-bottom: 0.5rem; }
      p.updated { font-size: 0.85rem; color: #666; margin-bottom: 1rem; }
      table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.95rem;
      }
      th, td {
        border: 1px solid #ddd;
        padding: 0.5rem 0.75rem;
        text-align: left;
        white-space: nowrap;
      }
      th { background: #f5f5f5; }
      td.price { text-align: right; }
      td.time { color: #888; font-size: 0.85rem; }
      a { color: #0066cc; text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <h1>日用品価格比較</h1>
    <p class="updated">最終更新: <%= generated_at %></p>
    <table>
      <thead>
        <tr>
          <th>商品</th>
          <th>Amazon</th>
          <th>Amazon取得時刻</th>
          <th>ヨドバシ</th>
          <th>ヨドバシ取得時刻</th>
        </tr>
      </thead>
      <tbody>
        <% products.each do |product| -%>
        <% id = product["id"] -%>
        <% data = prices[id] || {} -%>
        <% amazon = data["amazon"] -%>
        <% yodobashi = data["yodobashi"] -%>
        <% amazon_price = amazon ? amazon["price"] : nil -%>
        <% amazon_time = amazon ? amazon["fetched_at"] : nil -%>
        <% yodobashi_price = yodobashi ? yodobashi["price"] : nil -%>
        <% yodobashi_time = yodobashi ? yodobashi["fetched_at"] : nil -%>
        <% amazon_url = product["amazon_url"].to_s -%>
        <% yodobashi_url = product["yodobashi_url"].to_s -%>
        <tr>
          <td><%= ERB::Util.html_escape(product["name"]) %></td>
          <td class="price"><% if amazon_price && !amazon_url.empty? %><a href="<%= ERB::Util.html_escape(amazon_url) %>"><%= format_price(amazon_price) %></a><% else %><%= format_price(amazon_price) %><% end %></td>
          <td class="time"><%= format_time(amazon_time) %></td>
          <td class="price"><% if yodobashi_price && !yodobashi_url.empty? %><a href="<%= ERB::Util.html_escape(yodobashi_url) %>"><%= format_price(yodobashi_price) %></a><% else %><%= format_price(yodobashi_price) %><% end %></td>
          <td class="time"><%= format_time(yodobashi_time) %></td>
        </tr>
        <% end -%>
      </tbody>
    </table>
  </body>
  </html>
HTML

html = ERB.new(template, trim_mode: "-").result(binding)
File.write(OUTPUT_FILE, html)
puts "web/index.html を生成しました。"
