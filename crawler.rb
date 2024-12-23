require 'nokogiri'
require 'open-uri'
require 'sequel'

def fetch_amazon_products(query)
    base_url = 'https://www.amazon.pl/s'
    query_params = {
      'k' => query,
      '__mk_pl_PL' => '%C3%85M%C3%85%C5%BD%C3%95%C3%91',
      'crid' => '1QGGFVOVX31J5',
      'ref' => 'nb_sb_noss_2'
    }
    url = "#{base_url}?#{URI.encode_www_form(query_params)}"
    
    headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    retries = 3
    begin
        html = URI.open(url, headers)
        page = Nokogiri::HTML(html)
        puts "Fetching page: #{url}"

        page.css('div[role="listitem"]').each do |item|
            product_name = item.at_css('h2.a-size-base-plus')
            if product_name && !product_name.text.strip.empty?
                product_name = product_name.text.strip
            else
                next
            end

            asin = item['data-asin']

            price = item.at_css('.a-price .a-offscreen')
            price = price ? price.text.strip : "No price"

            link = item.at_css('a.a-link-normal')&.attribute('href')&.value
            product_url = "https://www.amazon.pl#{link}"
            product_details = fetch_product_details(product_url)
            
            puts "Product Name: #{product_name}"
            puts "Link: https://www.amazon.pl#{link}"
            puts "ASIN: #{asin}"
            puts "Price: #{price}"
            puts "Availability: #{product_details[:availability]}"
            puts "Brand: #{product_details[:brand]}"
            
            puts '-' * 40 
            DB[:products].insert(product: product_name, link: product_url, asin: asin, price: price, availability:product_details[:availability], brand:product_details[:brand])

        end
    rescue OpenURI::HTTPError => e
        if e.message.include?("503")
            retries -= 1
            if retries > 0
                puts "503 error, retrying in 5 seconds..."
                sleep 5
                retry
            else
                puts "Error 503 occurred. Please try again later."
            end
        else
            puts "Failed to fetch page: #{e.message}"
        end
    end
end

def fetch_product_details(product_url)
    
    headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    product_details = {}
    retries = 3
    begin
        sleep rand(3..7) 
        product_page = Nokogiri::HTML(URI.open(product_url, headers))
        availability_element = product_page.at_css('div#availability')
        if availability_element
            product_details[:availability] = availability_element&.text&.strip
        else
            product_details[:availability] = "No availability info"
        end
        brand = product_page.at_css('#bylineInfo_feature_div')

        if brand
            product_details[:brand] = brand&.text&.strip.sub("Marka: ", "")
        
        else
            product_details[:brand] = "No brand info"
        end
        
    rescue OpenURI::HTTPError => e
        retries -= 1
        puts "HTTP Error #{e.message}, retries left: #{retries}"
        if retries > 0
            sleep 5
            retry
        else
            puts "Failed to fetch product details for #{product_url}"
            product_details[:availability] = "Error fetching details"
            product_details[:brand] = "Error fetching details"
    end
    rescue => e
        puts "Error: #{e.message}"
        product_details[:availability] = "Error fetching details"
        product_details[:brand] = "Error fetching details"
    end
    product_details
end 


DB = Sequel.sqlite('products.db')

DB.create_table? :products do
  primary_key :id
  String :product
  String :link
  String :asin
  String :price
  String :availability
  String :brand
end

fetch_amazon_products("kubek termiczny")
