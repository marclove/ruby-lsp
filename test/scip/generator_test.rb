# typed: true
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/scip"
require "stringio"

module RubyLsp
  module SCIP
    class GeneratorTest < Minitest::Test
      #: -> void
      def test_generates_valid_protobuf_output
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          # Verify we get valid protobuf output
          result = output.string
          refute_empty(result)

          # Decode the output using google-protobuf
          index = Proto::Index.decode(result)
          refute_nil(index)
          refute_nil(index.metadata)
        end
      end

      #: -> void
      def test_output_contains_metadata
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          metadata = index.metadata
          refute_nil(metadata)
          assert_equal("ruby-lsp", metadata.tool_info.name)
          assert_match(%r{^file://}, metadata.project_root)
        end
      end

      #: -> void
      def test_output_contains_document_path
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          assert_equal(1, index.documents.length)

          document = index.documents.first
          assert_equal("example.rb", document.relative_path)
          assert_equal("Ruby", document.language)
        end
      end

      #: -> void
      def test_output_contains_class_symbol
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the class symbol
          symbol = document.symbols.find { |s| s.display_name == "Greeter" }
          refute_nil(symbol)
          assert_includes(symbol.symbol, "scip-ruby")
          assert_includes(symbol.symbol, "Greeter")
        end
      end

      #: -> void
      def test_output_contains_method_symbol
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
              def greet
                "hello"
              end
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the method symbol
          symbol = document.symbols.find { |s| s.display_name == "greet" }
          refute_nil(symbol)
          assert_includes(symbol.symbol, "greet")
        end
      end

      #: -> void
      def test_output_contains_documentation
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
              # Says hello to everyone
              def greet
                "hello"
              end
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the method symbol
          symbol = document.symbols.find { |s| s.display_name == "greet" }
          refute_nil(symbol)
          refute_empty(symbol.documentation)
          assert_includes(symbol.documentation.first, "Says hello")
        end
      end

      #: -> void
      def test_symbol_string_contains_namespace
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            module Foo
              class Bar
              end
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the nested class symbol
          symbol = document.symbols.find { |s| s.display_name == "Bar" }
          refute_nil(symbol)
          assert_includes(symbol.symbol, "Foo")
          assert_includes(symbol.symbol, "Bar")
        end
      end

      #: -> void
      def test_excludes_dependencies_by_default
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output, nil, include_dependencies: false)
          generator.generate

          index = Proto::Index.decode(output.string)
          # Should only have our example.rb
          assert_equal(1, index.documents.length)
          assert_equal("example.rb", index.documents.first.relative_path)
        end
      end

      #: -> void
      def test_generates_correct_output_for_modules
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            module MyModule
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          symbol = document.symbols.find { |s| s.display_name == "MyModule" }
          refute_nil(symbol)
          assert_equal(:Module, symbol.kind)
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
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the method with special character
          symbol = document.symbols.find { |s| s.display_name == "call?" }
          refute_nil(symbol)
          # Special identifiers should be escaped with backticks
          assert_includes(symbol.symbol, "`call?`")
        end
      end

      #: -> void
      def test_occurrences_have_valid_ranges
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Foo
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          refute_empty(document.occurrences)
          occurrence = document.occurrences.first
          # Range should have at least 3 elements (line, start_col, end_col)
          assert(occurrence.range.length >= 3)
          # First element is the line number (0-based)
          assert_equal(0, occurrence.range[0])
        end
      end

      #: -> void
      def test_method_documentation_includes_owner_and_file
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
              def greet(name)
                "Hello, \#{name}"
              end
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the method symbol
          symbol = document.symbols.find { |s| s.display_name == "greet" }
          refute_nil(symbol)
          refute_empty(symbol.documentation)
          doc = symbol.documentation.first

          # Should include owner class
          assert_includes(doc, "Greeter#greet")
          # Should include file location
          assert_includes(doc, "Defined in:")
          assert_includes(doc, "example.rb")
        end
      end

      #: -> void
      def test_class_documentation_includes_mixins
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            module Comparable
            end

            module Enumerable
            end

            class MyCollection
              include Enumerable
              prepend Comparable
            end
          RUBY

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          index = Proto::Index.decode(output.string)
          document = index.documents.first

          # Find the class symbol
          symbol = document.symbols.find { |s| s.display_name == "MyCollection" }
          refute_nil(symbol)
          refute_empty(symbol.documentation)
          doc = symbol.documentation.first

          # Should include mixin information
          assert_includes(doc, "Includes:")
          assert_includes(doc, "Enumerable")
          assert_includes(doc, "Prepends:")
          assert_includes(doc, "Comparable")
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
