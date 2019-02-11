require "simplecov"
SimpleCov.start
require 'pry'

require "httparty"
require 'webmock/rspec'

def file_fixture(filename)
  open(File.join(File.dirname(__FILE__), 'fixtures', "#{filename}")).read
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each {|f| require f}

RSpec.configure do |config|
  config.include HTTParty::StubResponse
  config.include HTTParty::SSLTestHelper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = false
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.disable_monkey_patching!

  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10

  config.order = :random

  config.before(:each) do
    # Reset default_cert_store cache
    HTTParty::ConnectionAdapter.instance_variable_set(:@default_cert_store, nil)
  end

  Kernel.srand config.seed
end

RSpec::Matchers.define :use_ssl do
  match(&:use_ssl?)
end

RSpec::Matchers.define :use_cert_store do |cert_store|
  match do |connection|
    connection.cert_store == cert_store
  end
end
