require 'config/requirements'
require 'config/hoe' # setup Hoe + all gem configuration
require "spec/rake/spectask"

Dir['tasks/**/*.rake'].each { |rake| load rake }

task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList["spec/**/*_spec.rb"]
end