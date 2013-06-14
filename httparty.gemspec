# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "httparty/version"

Gem::Specification.new do |s|
  s.name        = "httparty"
  s.version     = HTTParty::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["John Nunemaker", "Sandro Turriate"]
  s.email       = ["nunemaker@gmail.com"]
  s.homepage    = "http://jnunemaker.github.com/httparty"
  s.summary     = %q{Makes http fun! Also, makes consuming restful web services dead easy.}
  s.description = %q{Makes http fun! Also, makes consuming restful web services dead easy.}

  s.required_ruby_version     = '>= 1.9.3'

  s.add_dependency 'json',      "~> 1.8"
  s.add_dependency 'multi_xml', ">= 0.5.2"

  s.post_install_message = "When you HTTParty, you must party hard!"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
