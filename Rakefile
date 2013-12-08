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
  gem.files                 = %w( lib/**/* templates/**/* has_metadata.gemspec LICENSE README.md )
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'yard'

# bring sexy back (sexy == tables)
module YARD::Templates::Helpers::HtmlHelper
  def html_markup_markdown(text)
    markup_class(:markdown).new(text, :gh_blockcode, :fenced_code, :autolink, :tables, :no_intraemphasis).to_html
  end
end

YARD::Rake::YardocTask.new('doc') do |doc|
  doc.options << '-m' << 'markdown'
  doc.options << '-M' << 'redcarpet'
  doc.options << '--protected' << '--no-private'
  doc.options << '-r' << 'README.md'
  doc.options << '-o' << 'doc'
  doc.options << '--title' << 'has_metadata Documentation'

  doc.files = %w(lib/**/* README.md templates/metadata.rb)
end

task(default: :spec)
