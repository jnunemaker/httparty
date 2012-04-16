module HTTParty
  module SSLTestHelper
    def ssl_verify_test(mode, ca_basename, server_cert_filename)
      options = {
        :format  => :json,
        :timeout => 30,
      }

      if mode
        ca_path = File.expand_path("../../fixtures/ssl/generated/#{ca_basename}", __FILE__)
        raise ArgumentError.new("#{ca_path} does not exist") unless File.exist?(ca_path)
        options[mode] = ca_path
      end

      begin
        test_server = SSLTestServer.new({
          :rsa_key => File.read(File.expand_path("../../fixtures/ssl/generated/server.key", __FILE__)),
          :cert    => File.read(File.expand_path("../../fixtures/ssl/generated/#{server_cert_filename}", __FILE__)),
        })

        test_server.start

        HTTParty.get("https://localhost:#{test_server.port}/", options)
      ensure
        test_server.stop if test_server
      end
    end
  end
end
