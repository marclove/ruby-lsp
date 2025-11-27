# typed: strict
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/scip"
require "stringio"
require "json"

module RubyLsp
  module SCIP
    class GeneratorTest < Minitest::Test
      #: -> void
      def test_generates_valid_scip_metadata
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)

          # Check metadata
          metadata = scip_index["metadata"]
          refute_nil(metadata)
          assert_equal(0, metadata["version"])
          assert_equal("ruby-lsp", metadata.dig("tool_info", "name"))
          assert_match(%r{^file://}, metadata["project_root"])
          assert_equal(1, metadata["text_document_encoding"]) # UTF8
        end
      end

      #: -> void
      def test_generates_documents_array
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)

          # Check documents
          documents = scip_index["documents"]
          refute_nil(documents)
          assert(documents.is_a?(Array))
          assert_equal(1, documents.length)
        end
      end

      #: -> void
      def test_generates_document_with_relative_path
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first

          refute_nil(document)
          assert_equal("Ruby", document["language"])
          assert_equal("example.rb", document["relative_path"])
          assert_equal(2, document["position_encoding"]) # UTF16CodeUnitOffsetFromLineStart
        end
      end

      #: -> void
      def test_generates_occurrences_for_classes
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          occurrences = document["occurrences"]

          refute_empty(occurrences)
          class_occurrence = occurrences.first
          assert(class_occurrence["range"].is_a?(Array))
          assert_equal(0, class_occurrence["range"][0]) # Start line (0-based)
          refute_nil(class_occurrence["symbol"])
          assert_equal(1, class_occurrence["symbol_roles"]) # Definition
        end
      end

      #: -> void
      def test_generates_symbols_for_classes
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          symbols = document["symbols"]

          refute_empty(symbols)
          class_symbol = symbols.first
          refute_nil(class_symbol["symbol"])
          assert_equal(7, class_symbol["kind"]) # Class
          assert_equal("Greeter", class_symbol["display_name"])
        end
      end

      #: -> void
      def test_generates_documentation_for_methods
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
              # Says hello
              def greet
                "hello"
              end
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          symbols = document["symbols"]

          # Find the method symbol
          method_symbol = symbols.find { |s| s["display_name"] == "greet" }
          refute_nil(method_symbol)
          assert_equal(26, method_symbol["kind"]) # Method

          # Check documentation
          docs = method_symbol["documentation"]
          refute_nil(docs)
          assert(docs.is_a?(Array))
          refute_empty(docs)
          assert_match(/Says hello/, docs.first)
        end
      end

      #: -> void
      def test_generates_symbol_string_with_namespace
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            module Foo
              class Bar
              end
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          symbols = document["symbols"]

          # Find the nested class symbol
          bar_symbol = symbols.find { |s| s["display_name"] == "Bar" }
          refute_nil(bar_symbol)
          assert_match(%r{Foo/Bar#}, bar_symbol["symbol"])
        end
      end

      #: -> void
      def test_uses_correct_range_format_for_single_line
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          occurrences = document["occurrences"]

          # Single line should use 3-element range format
          class_occurrence = occurrences.first
          range = class_occurrence["range"]
          assert(range.length == 3 || range.length == 4)
        end
      end

      #: -> void
      def test_excludes_dependencies_by_default
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output, nil, include_dependencies: false)
          generator.generate

          scip_index = JSON.parse(output.string)
          documents = scip_index["documents"]

          # Should only have our example.rb, not any gems
          assert_equal(1, documents.length)
          assert_equal("example.rb", documents.first["relative_path"])
        end
      end

      #: -> void
      def test_generates_correct_kind_for_modules
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            module MyModule
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          symbols = document["symbols"]

          module_symbol = symbols.first
          assert_equal(29, module_symbol["kind"]) # Module
          assert_equal("MyModule", module_symbol["display_name"])
        end
      end

      #: -> void
      def test_escapes_special_identifiers
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Foo
              def call?
              end
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          scip_index = JSON.parse(output.string)
          document = scip_index["documents"].first
          symbols = document["symbols"]

          # Find the method with special character
          method_symbol = symbols.find { |s| s["display_name"] == "call?" }
          refute_nil(method_symbol)
          # Special identifiers should be escaped with backticks
          assert_match(/`call\?`/, method_symbol["symbol"])
        end
      end

      private

      #: { (String) -> void } -> void
      def with_temp_workspace(&block)
        Dir.mktmpdir do |dir|
          block.call(dir)
        end
      end
    end
  end
end
