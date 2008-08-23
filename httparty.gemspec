Gem::Specification.new do |s|
  s.name = %q{httparty}
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Nunemaker"]
  s.date = %q{2008-08-22}
  s.description = %q{Makes http fun! Also, makes consuming restful web services dead easy.}
  s.email = ["nunemaker@gmail.com"]
  s.extra_rdoc_files = ["History.txt", "License.txt", "Manifest.txt", "PostInstall.txt", "README.txt"]
  s.files = ["History.txt", "License.txt", "Manifest.txt", "PostInstall.txt", "README.txt", "Rakefile", "config/hoe.rb", "config/requirements.rb", "examples/aaws.rb", "examples/delicious.rb", "examples/twitter.rb", "examples/whoismyrep.rb", "httparty.gemspec", "lib/httparty.rb", "lib/httparty/core_ext.rb", "lib/httparty/core_ext/hash.rb", "lib/httparty/version.rb", "script/console", "script/destroy", "script/generate", "script/txt2html", "setup.rb", "spec/hash_spec.rb", "spec/httparty_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/deployment.rake", "tasks/environment.rake", "tasks/website.rake", "website/css/common.css", "website/index.html"]
  s.has_rdoc = true
  s.homepage = %q{http://httparty.rubyforge.org}
  s.post_install_message = %q{When you HTTParty, you must party hard!}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{httparty}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Makes http fun! Also, makes consuming restful web services dead easy.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<activesupport>, [">= 2.1"])
    else
      s.add_dependency(%q<activesupport>, [">= 2.1"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 2.1"])
  end
end