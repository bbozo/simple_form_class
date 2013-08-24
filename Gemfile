source 'https://rubygems.org'

gemspec

platforms :ruby do
  gem "sqlite3"
end

platforms :jruby do
  gem "minitest", ">= 3.0"
  gem "activerecord-jdbcsqlite3-adapter"
end

version = ENV["RAILS_VERSION"] || "3.2"

rails = case version
when "master"
  {github: "rails/rails"}
else
  "~> #{version}.0"
end

gem "rails", rails

gem 'minitest-colorize', :git => 'git://github.com/bbozo/minitest-colorize.git', :tag => 'v0.0.4.1'

gem 'strong_parameters' unless version == '4.0' || version == 'master'
