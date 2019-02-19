require 'pathname'

module HTTParty
  module SSLTestHelper
    def ssl_verify_test(mode, ca_basename, server_cert_filename, options = {}, &block)
      options = {
        format:  :json,
        timeout: 30
      }.merge(options)

      if mode
        ca_path = File.expand_path("../../fixtures/ssl/generated/#{ca_basename}", __FILE__)
        raise ArgumentError.new("#{ca_path} does not exist") unless File.exist?(ca_path)
        options[mode] = ca_path
      end

      begin
        test_server = SSLTestServer.new(
            rsa_key: File.read(File.expand_path("../../fixtures/ssl/generated/server.key", __FILE__)),
            cert:    File.read(File.expand_path("../../fixtures/ssl/generated/#{server_cert_filename}", __FILE__)))

        test_server.start

        if mode
          ca_path = File.expand_path("../../fixtures/ssl/generated/#{ca_basename}", __FILE__)
          raise ArgumentError.new("#{ca_path} does not exist") unless File.exist?(ca_path)
          return HTTParty.get("https://localhost:#{test_server.port}/", options, &block)
        else
          return HTTParty.get("https://localhost:#{test_server.port}/", options, &block)
        end
      ensure
        test_server.stop if test_server
      end

      test_server = SSLTestServer.new({
        rsa_key: path.join('server.key').read,
        cert:    path.join(server_cert_filename).read
      })

      test_server.start

      HTTParty.get("https://localhost:#{test_server.port}/", options, &block)
    ensure
      test_server.stop if test_server
    end
  end
end
