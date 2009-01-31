Dir[File.dirname(__FILE__) + "/parsers/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "httparty/parsers/#{filename}"
end
