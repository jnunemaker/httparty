require 'rake'
require File.expand_path('../lib/httparty', __FILE__)

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name        = "httparty"
    gem.summary     = %Q{Makes http fun! Also, makes consuming restful web services dead easy.}
    gem.description = %Q{Makes http fun! Also, makes consuming restful web services dead easy.}
    gem.email       = "nunemaker@gmail.com"
    gem.homepage    = "http://httparty.rubyforge.org"
    gem.authors     = ["John Nunemaker", "Sandro Turriate"]
    gem.version     = HTTParty::VERSION.dup

    gem.add_dependency 'crack', HTTParty::CRACK_DEPENDENCY

    gem.add_development_dependency "activesupport", "~>2.3"
    gem.add_development_dependency "cucumber", "~>0.7"
    gem.add_development_dependency "fakeweb", "~>1.2"
    gem.add_development_dependency "rspec", "~>1.3"
    gem.add_development_dependency "jeweler", "~>1.5"
    gem.add_development_dependency "mongrel", "1.2.0.pre2"
    gem.post_install_message = "When you HTTParty, you must party hard!"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.ruby_opts << '-rubygems'
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.spec_opts = ['--options', 'spec/spec.opts']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)

rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end

task :default => [:spec, :features]

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "httparty #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.include('lib/httparty.rb')
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.options = ['--verbose']
  end
rescue LoadError
end
