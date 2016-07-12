dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'

class StreamDownload
  include HTTParty

  base_uri 'https://cdn.kernel.org/pub/linux/kernel/v4.x'
end

# download file linux-4.6.4.tar.xz without using the memory
response = nil
filename = 'linux-4.6.4.tar.xz'

File.open(filename, 'w') do |file|
  response = StreamDownload.get('/linux-4.6.4.tar.xz', stream_body: true) do |fragment|
    file.binmode
    file.write(fragment)
  end
end

pp "Success: #{response.success?}"

pp File.stat(filename).inspect
