require 'spec_helper'

RSpec.describe "httparty.gemspec" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:files) do
    Dir.chdir(root) { Gem::Specification.load("httparty.gemspec").files }
  end

  it "packages the library and executable" do
    expect(files).to include("lib/httparty.rb", "bin/httparty")
  end

  it "leaves specs and cucumber features out of the gem" do
    expect(files.grep(%r{\A(test|spec|features)/})).to eq([])
  end

  it "leaves development files out of the gem" do
    expect(files.grep(%r{\A(\.github/|Gemfile|Guardfile|\.rubocop|script/)})).to eq([])
  end
end
