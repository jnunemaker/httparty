# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{httparty}
  s.version = "0.4.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Nunemaker"]
  s.date = %q{2009-04-23}
  s.default_executable = %q{httparty}
  s.description = %q{Makes http fun! Also, makes consuming restful web services dead easy.}
  s.email = %q{nunemaker@gmail.com}
  s.executables = ["httparty"]
  s.extra_rdoc_files = ["bin/httparty", "lib/httparty/cookie_hash.rb", "lib/httparty/core_extensions.rb", "lib/httparty/exceptions.rb", "lib/httparty/module_inheritable_attributes.rb", "lib/httparty/request.rb", "lib/httparty/response.rb", "lib/httparty/version.rb", "lib/httparty.rb", "README"]
  s.files = ["bin/httparty", "cucumber.yml", "examples/aaws.rb", "examples/basic.rb", "examples/delicious.rb", "examples/google.rb", "examples/rubyurl.rb", "examples/twitter.rb", "examples/whoismyrep.rb", "features/basic_authentication.feature", "features/command_line.feature", "features/deals_with_http_error_codes.feature", "features/handles_multiple_formats.feature", "features/steps/env.rb", "features/steps/httparty_response_steps.rb", "features/steps/httparty_steps.rb", "features/steps/mongrel_helper.rb", "features/steps/remote_service_steps.rb", "features/supports_redirection.feature", "History", "httparty.gemspec", "lib/httparty/cookie_hash.rb", "lib/httparty/core_extensions.rb", "lib/httparty/exceptions.rb", "lib/httparty/module_inheritable_attributes.rb", "lib/httparty/request.rb", "lib/httparty/response.rb", "lib/httparty/version.rb", "lib/httparty.rb", "Manifest", "MIT-LICENSE", "Rakefile", "README", "setup.rb", "spec/fixtures/delicious.xml", "spec/fixtures/empty.xml", "spec/fixtures/google.html", "spec/fixtures/twitter.json", "spec/fixtures/twitter.xml", "spec/fixtures/undefined_method_add_node_for_nil.xml", "spec/hash_spec.rb", "spec/httparty/cookie_hash_spec.rb", "spec/httparty/request_spec.rb", "spec/httparty/response_spec.rb", "spec/httparty_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "spec/string_spec.rb", "website/css/common.css", "website/index.html"]
  s.has_rdoc = true
  s.homepage = %q{http://httparty.rubyforge.org}
  s.post_install_message = %q{When you HTTParty, you must party hard!}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Httparty", "--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{httparty}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Makes http fun! Also, makes consuming restful web services dead easy.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<crack>, [">= 0.1.1"])
      s.add_development_dependency(%q<echoe>, [">= 0"])
    else
      s.add_dependency(%q<crack>, [">= 0.1.1"])
      s.add_dependency(%q<echoe>, [">= 0"])
    end
  else
    s.add_dependency(%q<crack>, [">= 0.1.1"])
    s.add_dependency(%q<echoe>, [">= 0"])
  end
end
