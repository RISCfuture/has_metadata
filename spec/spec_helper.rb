require 'bundler'
Bundler.require :default, :development
require 'active_support'
require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'has_metadata'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'test.sqlite'
)
require "#{File.dirname __FILE__}/../templates/metadata"

RSpec.configure do |config|
  config.before(:each) do
    Metadata.connection.execute "DROP TABLE IF EXISTS metadata"
    Metadata.connection.execute "CREATE TABLE metadata (id INTEGER PRIMARY KEY ASC, data TEXT)"
    Metadata.connection.execute "DROP TABLE IF EXISTS users"
    Metadata.connection.execute "CREATE TABLE users (id INTEGER PRIMARY KEY ASC, metadata_id INTEGER, login VARCHAR(100))"
  end
end
