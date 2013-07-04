require 'rubygems'
require 'bundler'

Bundler.require

require 'tmpdir'
require 'fileutils'
require 'json'

class Project
  def self.eval repo, &block
    setup repo
    yield
    cleanup
  end

  def self.setup repo
    @temp_path = "#{Time.now.to_i}-#{rand(100)}"
    download_source_code repo, @temp_path
  end

  def self.cleanup
    FileUtils.rm_rf @temp_path
  end

  def self.download_source_code repo, destination=nil
    return if repo.nil?

    git = Cocaine::CommandLine.new("git", "clone :repo :destination")
    git.run repo: repo, destination: destination
  end

  def self.files_of_type filetype, directory=""
    extensions = {
      :ruby  => ".rb",
      :rspec => "_spec.rb"
    }
    Dir.glob "#{@temp_path}#{directory}/**/*#{extensions[filetype]}"
  end
end

class RailsProject < Project
  def self.models
    files_of_type :ruby, "app/models"
  end

  def self.specs
    files_of_type :rspec, "/spec"
  end
end

class LanternReporter
  include MiniTest::Reporter

  def initialize
    @results = {}
  end

  def failure suite, test, test_runner
    @results[test] = false
  end

  def pass suite, test, test_runner
    @results[test] = true
  end

  def after_suites(suites, type)
    summary = { :score => calculate_score(@results), :tests => @results }
    puts summary.to_json
  end

  private

  def calculate_score results
    results.values.count { |t| t == true }
  end
end


### This part is project specific

class ProjectTest < MiniTest::Unit::TestCase
  def test_that_there_are_atleast_six_models
    assert RailsProject.models.length >= 6
  end

  def test_that_there_are_tests
    assert RailsProject.specs.length >= 1
  end
end

if ARGV.empty?
  puts "Usage: #{$0} repo"
  exit 1
end

RailsProject.eval ARGV.first do
  MiniTest::Reporters.use! LanternReporter.new
  MiniTest::Unit.new.run
end
