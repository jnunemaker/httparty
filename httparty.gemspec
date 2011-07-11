# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "httparty/version"

Gem::Specification.new do |s|
  s.name        = "httparty"
  s.version     = HTTParty::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["John Nunemaker", "Sandro Turriate"]
  s.email       = ["nunemaker@gmail.com"]
  s.homepage    = "http://httparty.rubyforge.org/"
  s.summary     = %q{Makes http fun! Also, makes consuming restful web services dead easy.}
  s.description = %q{Makes http fun! Also, makes consuming restful web services dead easy.}

  s.add_dependency "activesupport", "~> 3.0"
  s.add_dependency "multi_json",    "~> 1.0"
  s.add_dependency "multi_xml",     "~> 0.2"

  s.add_development_dependency "activesupport", "~> 3.0"
  s.add_development_dependency "cucumber",      "~> 1.0"
  s.add_development_dependency "fakeweb",       "~> 1.2"
  s.add_development_dependency "rspec",         "~> 2.6"
  s.add_development_dependency "mongrel",       "1.2.0.pre2"

  s.post_install_message = "When you HTTParty, you must party hard!"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
