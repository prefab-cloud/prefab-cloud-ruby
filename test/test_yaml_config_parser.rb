# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestYamlConfigParser < Minitest::Test
  def setup
    super
    # Path to the file we want to use in the test
    @empty_file = Tempfile.new(['empty_file', '.yml'])

    # Providing the file exists, ensure it's empty for the test
    File.write(@empty_file.path, '')

    Prefab.init(prefab_options)

    @config_parser = Prefab::YAMLConfigParser.new(@empty_file.path, nil)
  end

  def test_empty_file_loading
    # Ensure no error raised when loading an empty filer
    @config_parser.merge({})
    assert_logged(/^WARN.+Empty file.+\.yml$/)
  end
end
