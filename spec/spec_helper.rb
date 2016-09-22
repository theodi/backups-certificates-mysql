require 'mysql2'
require 'fog'
require 'dotenv'
require 'httparty'

Dotenv.load

require_relative 'lib/setup.rb'

INSTANCE = ENV['INSTANCE']
DATABASE = ENV['DB']
DATABASE_USER = ENV['DB_USER']
DATABASE_PASS = ENV['DB_PASS']

RSpec.configure do |config|
  config.before(:all) do
    spin_up

    @client = Mysql2::Client.new host: @lb_ip,
                                 database: DATABASE,
                                 username: DATABASE_USER,
                                 password: DATABASE_PASS
  end

  config.after(:all) do
    tear_down
  end
end
