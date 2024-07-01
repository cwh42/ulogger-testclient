#!/usr/bin/env ruby
require 'nokogiri'
require 'net/http'
require 'json'
require 'date'

gpx_file = ARGV[0]
@uri = URI('http://192.168.178.95:8080')

hostname = @uri.hostname
@uri.path = '/ulogger/client/index.php'
#req.content_type = 'application/x-www-form-urlencoded'

unless gpx_file
  puts "Usage: #{__FILE__} GPXFILE"
  exit 1
end

def get_data(node, keys, ns = 'xmlns')
  return unless node
  
  keys.filter_map do |key|
    val = node.at("#{ns}|#{key}")&.text
    [key, val] if val
  end.to_h
end

def addtrack(trkname)
  data = { action: 'addtrack', track: trkname }

  res = Net::HTTP.post_form(@uri, data)
  
  if res.code == "200"
    result = JSON.parse(res.body)
  else
    puts res.body
    exit
  end
  
  result['trackid']
end

def addpos(trackid, data)
  data = { action: 'addpos', trackid: trackid }.merge(data)
  
  res = Net::HTTP.post_form(@uri, data)
  
  if res.code == "200"
    result = JSON.parse(res.body)
  else
    puts res.body
    exit
  end
  
  result
end

doc = Nokogiri::XML(open(gpx_file))
trk = doc.at('trk')
trkname = trk.at('name')&.text || Time.now.strftime("%Y-%m-%d %H:%M:%S")
trkpts = trk.css('trkpt')

trackid = addtrack(trkname)
puts "#{trkname} -> #{trackid}"
trkpts.each do |trkpt|
  lat = trkpt.at('@lat')
  lon = trkpt.at('@lon')

  data = get_data(trkpt, %w[ele time]).transform_keys('ele' => 'altitude')
  time = data['time'] ? DateTime.parse(data['time']) : Time.now
  data['time'] = time.strftime('%s')
  
  ext = trkpt.at('extensions')
  extensions = get_data(ext, %w[speed bearing accuracy provider], 'ulogger') || {}

  puts "-> #{lat} #{lon} #{data} #{extensions}"
  addpos(trackid, {'lat' => lat, 'lon' => lon}.merge(data, extensions))
  
  sleep(1)
end

