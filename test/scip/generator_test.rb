# typed: strict
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/scip"
require "stringio"

module RubyLsp
  module SCIP
    class GeneratorTest < Minitest::Test
      #: -> void
      def test_generates_protobuf_output
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          output.binmode
          generator = Generator.new(workspace_path, output)
          generator.generate

          # Verify we get output (not empty)
          result = output.string
          refute_empty(result)
          # Protobuf binary should be binary encoded
          assert_equal(Encoding::BINARY, result.encoding)
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

          result = output.string
          # The output should contain "ruby-lsp" string (tool name)
          assert_includes(result, "ruby-lsp")
          # The output should contain the project root
          assert_includes(result, "file://")
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

          result = output.string
          # The output should contain the relative path
          assert_includes(result, "example.rb")
          # The output should contain the language
          assert_includes(result, "Ruby")
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

          result = output.string
          # The output should contain the symbol string
          assert_includes(result, "Greeter")
          assert_includes(result, "scip-ruby")
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

          result = output.string
          # The output should contain the method name
          assert_includes(result, "greet")
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

          result = output.string
          # The output should contain the documentation
          assert_includes(result, "Says hello")
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

          result = output.string
          # The output should contain namespace path
          assert_includes(result, "Foo")
          assert_includes(result, "Bar")
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

          result = output.string
          # Should only have our example.rb
          assert_includes(result, "example.rb")
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

          result = output.string
          assert_includes(result, "MyModule")
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

          result = output.string
          # Special identifiers should be escaped with backticks
          assert_includes(result, "`call?`")
        end
      end

      #: -> void
      def test_proto_encoder_writes_valid_varint
        encoder = Proto::Encoder.new
        encoder.write_varint(150)
        # 150 = 0x96 0x01 in varint encoding
        assert_equal("\x96\x01".b, encoder.to_s)
      end

      #: -> void
      def test_proto_encoder_writes_string
        encoder = Proto::Encoder.new
        encoder.write_string(1, "test")
        # Field 1, wire type 2 (length-delimited) = tag 0x0a
        # Length 4 = 0x04
        # "test" bytes
        assert_equal("\x0a\x04test".b, encoder.to_s)
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
