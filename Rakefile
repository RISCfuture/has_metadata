require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name                  = "has_metadata"
  gem.summary               = %Q{Reduce your table width by moving non-indexed columns to a separate metadata table}
  gem.description           = %Q{has_metadata lets you move non-indexed and weighty columns off of your big tables by creating a separate metadata table to store all this extra information. Works with Ruby 1.9. and Rails 3.0.}
  gem.email                 = "git@timothymorgan.info"
  gem.homepage              = "http://github.com/riscfuture/has_metadata"
  gem.authors               = ["Tim Morgan"]
  gem.required_ruby_version = '>= 1.9'
  gem.files                 = %w( lib/**/* templates/**/* has_metadata.gemspec LICENSE README.textile )
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'yard'
YARD::Rake::YardocTask.new('doc') do |doc|
  doc.options << "-m" << "textile"
  doc.options << "--protected"
  doc.options << "-r" << "README.textile"
  doc.options << "-o" << "doc"
  doc.options << "--title" << "has_metadata Documentation"

  doc.files = ['lib/**/*', 'README.textile', 'templates/metadata.rb']
end

task(default: :spec)
