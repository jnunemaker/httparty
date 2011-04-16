require 'bundler'
Bundler::GemHelper.install_tasks

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.ruby_opts << '-rubygems'
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.spec_opts = ['--options', 'spec/spec.opts']
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features)

task :default => [:spec, :features]