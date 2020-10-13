require 'rubygems'
require 'mechanize'

agent = Mechanize.new
puts agent.get(ARGV[0]).inspect
