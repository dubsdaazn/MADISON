require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'csv'
require 'rexml/document'
require 'net/http'

# page = Hpricot( open( 'http://www.gwinnettcountysheriff.com/asp/docket48hr.asp' ))
#page = Hpricot( open( 'http://www.planetargon.com/about.html' ) )    

# parsedPage = page.search( "//tr" ).each do |row|
#     puts row.search("//td[3]//text()")
# end

doc = Hpricot(open('http://www.gwinnettcountysheriff.com/asp/docket48hr.asp').read)
listing = []

doc.search("//table//tr").each { |tr_item|
    offender_row = {
        "last_name"=>(tr_item.search("//td")[2].search("/font").innerHTML).strip,
        "first_name"=>(tr_item.search("//td")[3].search("/font").innerHTML).strip,
        "address"=>(tr_item.search("//td")[7].search("/font").innerHTML).strip,
        "offender_id"=>(tr_item.search("//td")[6].search("/font").innerHTML).strip,
        "city_state"=>"",
        "street"=>"",
        "charge"=>(tr_item.search("//td")[8].search("/font").innerHTML).strip
        
    }
    listing << offender_row
}

# Make list for people with holds (offender_id)
hold_list_ids = listing.each_with_object([]) do |list, arr|
  arr << "#{list['offender_id']}" if list["charge"].include? "HOLD"
end

#removing any records associated with a hold or if it matches these charge strings
listing.reject! do |list|
  (hold_list_ids.include?("#{list['offender_id']}") || (list["address"] == ",") || (list["charge"].empty?) || list['charge'].include?("VALID") || 
  list['charge'].include?("OBSCURING LIC") || list['charge'].include?("IMPROPER USE") || list['charge'].include?("RESIDENT") || list['charge'].include?("PLATE TO CONCEAL") || 
  list['charge'].include?("SIMPLE BATTERY"))
end

#remove if you don't have these strings in the charge
listing.reject! do |list|
  !(list['charge'].include?(" LIC") || list['charge'].include?("ALCOHOL") || list['charge'].include?("DUI") || list['charge'].include?("DRUG") || 
  list['charge'].include?("BATTERY") || list['charge'].include?("MARIJ") || (list['charge'].include?("THEFT") && list['charge'].include?('SHOPLIFTING')) || 
  list['charge'].include?(" UNLIC") || list['charge'].include?("VGCSA") || list['charge'].include?('Alcohol'))
end

#Only Unique entries
listing.uniq!{|list| list['offender_id']}

#getting 9 digit zip code for addresses
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

#create a CSV
CSV.open("offenders_list.csv", "wb") do |csv|
  csv << ["Title", "First name", "Last Name"]
  listing.each do |list|
    csv << ["#{list['first_name']} #{list['last_name']}", list['street'],list['city_state']]
  end
end