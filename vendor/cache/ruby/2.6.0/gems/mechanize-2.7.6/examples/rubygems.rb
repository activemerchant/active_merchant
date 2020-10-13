# This example logs a user in to rubyforge and prints out the body of the
# page after logging the user in.
require 'rubygems'
require 'mechanize'
require 'logger'

# Create a new mechanize object
mech = Mechanize.new
mech.log = Logger.new $stderr
mech.agent.http.debug_output = $stderr

# Load the rubyforge website
page = mech.get('https://rubygems.org/')
page = mech.click page.link_with(:text => /Sign in/) # Click the login link
form = page.forms[1] # Select the first form
form["session[who]"] = ARGV[0]
form["session[password]"] = ARGV[1]
form["commit"] = "Sign in"

# Submit the form
page = form.submit form.buttons.first

puts page.body # Print out the body
