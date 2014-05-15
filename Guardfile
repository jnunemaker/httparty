rspec_options = {
  version:        1,
  all_after_pass: false,
  all_on_start:   false,
}

guard 'rspec', rspec_options do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end

guard 'bundler' do
  watch('Gemfile')
  watch(/^.+\.gemspec/)
end
