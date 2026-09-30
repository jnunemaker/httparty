require 'socket'
require 'uri'

class PersistentHTTPTestServer
  attr_reader :port

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.local_address.ip_port
    @connections = []
    @paths = []
    @client_threads = []
    @mutex = Mutex.new
    @running = true
    @accept_thread = Thread.new { accept_connections }
  end

  def connection_count
    @mutex.synchronize { @connections.length }
  end


  def paths
    @mutex.synchronize { @paths.dup }
  end

  def stop
    @running = false
    @server.close
    @mutex.synchronize { @connections.each { |socket| socket.close unless socket.closed? } }
    @accept_thread.join(1)
    @client_threads.each { |thread| thread.join(1) }
  end

  private

  def accept_connections
    while @running
      socket = @server.accept
      @mutex.synchronize { @connections << socket }
      @client_threads << Thread.new { serve(socket) }
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def serve(socket)
    while (request_line = socket.gets)
      break if request_line.strip.empty?

      path = request_line.split(' ')[1]
      path = URI(path).request_uri if path.start_with?('http://', 'https://')
      @mutex.synchronize { @paths << path }
      headers = read_headers(socket)
      respond(socket, path)
      break if headers['connection']&.casecmp('close')&.zero?
    end
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE
    nil
  ensure
    socket.close unless socket.closed?
  end

  def read_headers(socket)
    headers = {}
    while (line = socket.gets)
      break if line == "\r\n"

      name, value = line.split(':', 2)
      headers[name.downcase] = value.strip
    end
    headers
  end

  def respond(socket, path)
    case path
    when '/redirect'
      socket.write "HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nConnection: keep-alive\r\n\r\n"
    when '/slow'
      sleep 0.1
      write_ok(socket, 'slow')
    when '/stream'
      socket.write "HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: keep-alive\r\n\r\n"
      socket.write 'one'
      sleep 0.01
      socket.write 'two'
    else
      write_ok(socket, path == '/final' ? 'final' : 'ok')
    end
  end

  def write_ok(socket, body)
    socket.write "HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: keep-alive\r\n\r\n#{body}"
  end
end
