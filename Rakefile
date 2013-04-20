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

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/{functional,unit}/**/*_test.rb'
end

namespace :test do
  Rake::TestTask.new(:lint) do |test|
    test.libs << 'lib' << 'test'
    test.pattern = 'test/test_active_model_lint.rb'
  end

  task :all => ['test', 'test:lint']
end


namespace "test" do
  task "all" => ["unit"]

  def test_task(name)
    desc "Run #{name} tests"
    Rake::TestTask.new(name) do |t|
      t.pattern = "test/#{name}/**/*_test.rb"
    end
  end

  test_task "unit"

  desc "Run integration tests"
  task "integration" => ["db:setup", "integration:all"]

  namespace "integration" do
    task "all" => ["development", "production", "test"]

    ["development", "production"].each do |environment|
      task environment do
        Rake::Task["test:integration:run"].execute environment
      end
    end

    task "run" do |t, environment|
      puts "Running integration tests in #{environment}"

      ENV["RAILS_ENV"] = environment
      success = system("testrb -I test/integration")

      raise "Integration tests failed in #{environment}" unless success
    end

    task "test" do
      puts "Running rake in dummy app"
      ENV["RAILS_ENV"] = "test"
      run_in_dummy_app "rake"
    end
  end
end

namespace "db" do
  desc "Set up databases for integration testing"
  task "setup" do
    puts "Setting up databases"
    run_in_dummy_app "rm -f db/*.sqlite3"
    run_in_dummy_app "RAILS_ENV=development rake db:schema:load db:seed"
    run_in_dummy_app "RAILS_ENV=production rake db:schema:load db:seed"
    run_in_dummy_app "RAILS_ENV=test rake db:schema:load"
  end
end
