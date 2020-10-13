require 'rubygems'
require 'mechanize'

agent = Mechanize.new

# Get the flickr sign in page
page  = agent.get 'http://flickr.com/signin/flickr/'

# Fill out the login form
form          = page.form_with :name => 'flickrloginform'
form.email    = ARGV[0]
form.password = ARGV[1]
form.submit

# Go to the upload page
page  = page.link_with(:text => 'Upload').click

# Fill out the form
form  = page.forms.action('/photos_upload_process.gne').first
form.file_uploads.name('file1').first.file_name = ARGV[2]
form.submit

