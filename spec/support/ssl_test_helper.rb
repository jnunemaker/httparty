require 'pathname'

module HTTParty
  module SSLTestHelper
    def ssl_verify_test(mode, ca_basename, server_cert_filename)
      path = Pathname(__FILE__).join('..', '..', 'fixtures', 'ssl', 'generated').expand_path
      options = {
        :format  => :json,
        :timeout => 30,
      }

      if mode
        ca_path = path.join(ca_basename)
        raise ArgumentError.new("#{ca_path} does not exist") unless ca_path.exist?
        options[mode] = ca_path
      end

      test_server = SSLTestServer.new({
        :rsa_key => path.join('server.key').read,
        :cert    => path.join(server_cert_filename).read,
      })

      test_server.start

      HTTParty.get("https://localhost:#{test_server.port}/", options)
    ensure
      test_server.stop if test_server
    end
  end
end
