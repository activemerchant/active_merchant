require 'rubygems'
require 'mechanize'

agent = Mechanize.new
agent.set_proxy('localhost', '8000')
page = agent.get(ARGV[0])
puts page.body
