require 'rake'
require 'bundler/gem_tasks'
require 'rake/testtask'

def run_in_dummy_app(command)
  success = system("cd test/dummy && #{command}")
  raise "#{command} failed" unless success
end

task "default" => "ci"

desc "Run all tests for CI"
task "ci" => "test"

desc "Run all tests"
task "test" => "test:all"

namespace "test" do
  task "all" => ["db:setup", "unit"]

  def test_task(name)
    desc "Run #{name} tests"
    Rake::TestTask.new(name) do |t|
      t.libs << "test"
      t.pattern = "test/#{name}/**/*_test.rb"
    end
  end

  test_task "unit"
end

namespace "db" do
  desc "Set up databases for integration testing"
  task "setup" do
    puts "Setting up development, production & test databases in parallel"
    run_in_dummy_app "rm -f db/*.sqlite3"

    threads = []
    threads << Thread.new{ run_in_dummy_app "RAILS_ENV=development rake db:schema:load db:seed" }
    threads << Thread.new{ run_in_dummy_app "RAILS_ENV=production rake db:schema:load db:seed" }
    threads << Thread.new{ run_in_dummy_app "RAILS_ENV=test rake db:schema:load" }

    threads.each(&:join)
  end
end
