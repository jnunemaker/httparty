module HTTParty
  module SSLTestHelper
    def ssl_verify_test(mode, ca_basename, server_cert_filename)
      test_server = nil
      begin
        # Start an HTTPS server
        test_server = SSLTestServer.new(
            :rsa_key => File.read(File.expand_path("../../fixtures/ssl/generated/server.key", __FILE__)),
            :cert => File.read(File.expand_path("../../fixtures/ssl/generated/#{server_cert_filename}", __FILE__)))
        test_server.start

        # Build a request
        if mode
          ca_path = File.expand_path("../../fixtures/ssl/generated/#{ca_basename}", __FILE__)
          raise ArgumentError.new("#{ca_path} does not exist") unless File.exist?(ca_path)
          return HTTParty.get("https://localhost:#{test_server.port}/", :format => :json, :timeout=>30, mode => ca_path)
        else
          return HTTParty.get("https://localhost:#{test_server.port}/", :format => :json, :timeout=>30)
        end
      ensure
        test_server.stop if test_server
      end
    end
  end
end
