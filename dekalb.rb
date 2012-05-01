require 'rubygems'
require 'open-uri'
require 'csv'
require 'rexml/document'
require 'net/http'

#generating list from csv
listing = []
CSV.foreach("meh.csv") do |list|
  row = {
    "name"=>list[0],
    "street"=>list[1],
    "city_state"=>list[2],
    "address"=>"#{list[1]} #{list[2]}"
  }
  listing << row
end

#Making api call to yahoo maps
listing.each do |list|
    begin
      apt = ''
      if list['address'] =~ /(APT\s+\w+\s+)/
        apt = "#{$1}"
        list['address'].gsub!(apt, '')
      end    
      url = "http://where.yahooapis.com/geocode?q=#{list['address'].gsub(' ', '+').gsub(',', '%2C')}"
      xml_data = Net::HTTP.get_response(URI.parse(url)).body
      doc = REXML::Document.new(xml_data)
      list['street'] = "#{apt}#{doc.elements['ResultSet'].elements['Result'].elements['line1'].text}" 
      list['city_state'] = "#{doc.elements['ResultSet'].elements['Result'].elements['line2'].text}"
    rescue
      
    end
end

#switching names

listing.each do |list|
  name_array = list['name'].split(',')
  list['name'] = "#{name_array[1]} #{name_array[0]}"
end

#create a CSV
CSV.open("meh.csv", "wb") do |csv|
  csv << ["Title", "First name", "Last Name"] 
  listing.each do |list|
    csv << [list['name'], list['street'],list['city_state']]
  end
end