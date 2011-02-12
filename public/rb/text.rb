#!/usr/bin/env ruby
#
# A simple example app using the Socrata Open Data API and the Tropo IVR API
# - http://dev.socrata.com
# - http://www.tropo.com
#

require 'net/http'
require 'uri'
require 'json'
require 'cgi'

# Config:
DOMAIN = "data.baltimorecity.gov"
UID = "843n-5pix"
RANGE = 500 # Meters

class String
  def underscore
    self.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      gsub(/[^A-z_0-9]+/, '_').
      downcase
  end
end

class Crime
  def self.set_columns(cols)
    @@col_map = Hash.new
    @@location_columns = []
    cols.each_with_index { |col, idx| 
      @@col_map[col["name"].underscore] = idx
      @@location_columns << idx if col["dataTypeName"] == "location"
    }
  end

  def initialize(entry)
    @row = entry
  end

  def location
    # For now we just return the first location column...
    Point.new(@row[@@location_columns[0]][1], @row[@@location_columns[0]][2])
  end

  def method_missing(m)
    if @@col_map.include?(m.to_s.underscore)
      @row[@@col_map[m.to_s.underscore]]
    end
  end

  # Performs the actual lookup and retuns an array of entries
  # Range is in meters
  def self.lookup(location, range)
    query = {
      "originalViewId" => UID,
      "name" => "Inline View",
      "query" => {
        "filterCondition" => {
           "children" => [
              {
                 "type" => "operator",
                 "value" => "AND",
                 "children" => [
                    {
                       "type" => "operator",
                       "value" => "WITHIN_CIRCLE",
                       "children" => [
                          {
                             "type" => "column",
                             "columnId" => 2631348
                          },
                          {
                             "type" => "literal",
                             "value" => location.latitude
                          },
                          {
                             "type" => "literal",
                             "value" => location.longitude
                          },
                          {
                             "type" => "literal",
                             "value" => range
                          }


                       ]
                    }
                 ]
              }
           ],
           "type" => "operator",
           "value" => "AND"
        }
      }
    }

    request = Net::HTTP::Post.new("/api/views/INLINE/rows.json?method=index")
    request.add_field("X-APP-TOKEN", "An7lKFieeU9qgHhuJMN1MVYcJ")
    request.body = query.to_json
    request.content_type = "application/json"
    response = Net::HTTP.start(DOMAIN, 80){ |http| http.request(request) }

    if response.code != "200"
      raise "Error querying SODA API: #{response.body}"
    else
      view = JSON::parse(response.body)
      if view["meta"].nil? || view["data"].nil?
        raise "Could not parse server response"
      elsif view["data"].size <= 0
        # No results
        return []
      end

      Crime.set_columns(view["meta"]["view"]["columns"])
      return view["data"].collect{ |row| Crime.new(row) }
    end
  end
end

class Point
  attr_accessor :latitude, :longitude, :address

  # Initialize a point based off an address or set of points
  def initialize(*args)
    case args.size
    when 1
      # Address
      @address = args[0].to_s

      # Geocode the address
      request = Net::HTTP::Get.new("/api/geocoding/#{CGI::escape(@address)}")
      request.add_field("X-APP-TOKEN", "An7lKFieeU9qgHhuJMN1MVYcJ")
      response = Net::HTTP.start(DOMAIN, 80){ |http| http.request(request) }
      point = JSON::parse(response.body)
      if point.nil? || !point.key?("lat") || !point.key?("long")
        return
      end

      @latitude = point["lat"]
      @longitude = point["long"]

    when 2
      # Lat/Long
      @latitude = args[0].to_f
      @longitude = args[1].to_f
    end
  end
end

# Handles message requests
def message(zip_code)
  begin
    # Geocode our zip code
    point = Point.new(zip_code)

    # Look up nearby crimes
    crimes = Crime.lookup(point, RANGE)

    if crimes.nil? || crimes.size <= 0
      say "You've found a mysterious corner of Baltimore that is crime free. You should buy real estate."
    elsif crimes.size < 100
      say "I found only #{crimes.size} crime reports in your area. You're probably safe to walk."
    elsif crimes.size >= 100 && crimes.size < 500
      say "There have been #{crimes.size} crimes reported in your area. You probably want to take a cab."
    else
      say "RUNNNNNNNNNNNNNNNNNNNNNNNNNN!!!! (#{crimes.size} reported crimes)"
    end
  rescue Exception => e
    say "An error has occurred. I'm sorry for the trouble."
    log e.message
  end
end

answer

# Decide whether this is text or phone
if $currentCall.nil?
  log "Curious. No currentCall. Am I running outside Tropo?"
elsif $currentCall.initialText =~ /^\d{5}$/
  # Text message, proper zip code
  message($currentCall.initialText)
else
  # Text message, invalid zip code
  say("Please text me a valid zip code to see whether your drunk a$$ should walk or take a cab.")
end

hangup
