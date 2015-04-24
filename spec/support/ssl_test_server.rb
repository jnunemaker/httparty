require 'openssl'
require 'socket'
require 'thread'

# NOTE: This code is garbage.  It probably has deadlocks, it might leak
# threads, and otherwise cause problems in a real system.  It's really only
# intended for testing HTTParty.
class SSLTestServer
  attr_accessor :ctx    # SSLContext object
  attr_reader :port

  def initialize(options = {})
    @ctx             = OpenSSL::SSL::SSLContext.new
    @ctx.cert        = OpenSSL::X509::Certificate.new(options[:cert])
    @ctx.key         = OpenSSL::PKey::RSA.new(options[:rsa_key])
    @ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE   # Don't verify client certificate
    @port            = options[:port] || 0
    @thread          = nil
    @stopping_mutex  = Mutex.new
    @stopping        = false
  end

  def start
    @raw_server = TCPServer.new(@port)

    if @port == 0
      @port = Socket.getnameinfo(@raw_server.getsockname, Socket::NI_NUMERICHOST | Socket::NI_NUMERICSERV)[1].to_i
    end

    @ssl_server = OpenSSL::SSL::SSLServer.new(@raw_server, @ctx)

    @stopping_mutex.synchronize {
      return if @stopping
      @thread = Thread.new { thread_main }
    }

    nil
  end

  def stop
    @stopping_mutex.synchronize {
      return if @stopping
      @stopping = true
    }
    @thread.join
  end

  private

  def thread_main
    until @stopping_mutex.synchronize { @stopping }
      (rr, _, _) = select([@ssl_server.to_io], nil, nil, 0.1)

      next unless rr && rr.include?(@ssl_server.to_io)

      socket = @ssl_server.accept

      Thread.new {
        header = []

        until (line = socket.readline).rstrip.empty?
          header << line
        end

        response = <<EOF
HTTP/1.1 200 OK
Connection: close
Content-Type: application/json; charset=UTF-8

{"success":true}
EOF

        socket.write(response.gsub(/\r\n/n, "\n").gsub(/\n/n, "\r\n"))
        socket.close
      }
    end

    @ssl_server.close
  end
end
