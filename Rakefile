# frozen_string_literal: true

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task default: :test

unless ENV['CI']
  require 'juwelier'
  Juwelier::Tasks.new do |gem|
    # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
    gem.name = 'prefab-cloud-ruby'
    gem.homepage = 'http://github.com/prefab-cloud/prefab-cloud-ruby'
    gem.license = 'MIT'
    gem.summary = %(Prefab Ruby Infrastructure)
    gem.description = %(Feature Flags, Live Config, and Dynamic Log Levels as a service)
    gem.email = 'jdwyer@prefab.cloud'
    gem.authors = ['Jeff Dwyer']

    # dependencies defined in Gemfile
  end
  Juwelier::RubygemsDotOrgTasks.new

  desc 'Code coverage detail'
  task :simplecov do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test'].execute
  end

  require 'rdoc/task'
  Rake::RDocTask.new do |rdoc|
    version = File.exist?('VERSION') ? File.read('VERSION') : ''

    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "prefab-cloud-ruby #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
end
