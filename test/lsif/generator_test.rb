# typed: strict
# frozen_string_literal: true

require "test_helper"
require "ruby_lsp/lsif"
require "stringio"
require "json"

module RubyLsp
  module LSIF
    class GeneratorTest < Minitest::Test
      #: -> void
      def test_generates_valid_lsif_metadata
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }

          # First line should be metadata
          metadata = lines[0]
          assert_equal("vertex", metadata["type"])
          assert_equal("metaData", metadata["label"])
          assert_equal("0.6.0", metadata["version"])
          assert_equal("utf-16", metadata["positionEncoding"])
          assert_equal("ruby-lsp", metadata.dig("toolInfo", "name"))
        end
      end

      #: -> void
      def test_generates_project_vertex
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }

          # Second line should be project
          project = lines[1]
          assert_equal("vertex", project["type"])
          assert_equal("project", project["label"])
          assert_equal("ruby", project["kind"])
        end
      end

      #: -> void
      def test_generates_document_vertex_for_ruby_files
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          document = lines.find { |line| line["label"] == "document" }

          refute_nil(document)
          assert_equal("vertex", document["type"])
          assert_equal("ruby", document["languageId"])
          assert_match(/example\.rb$/, document["uri"])
        end
      end

      #: -> void
      def test_generates_range_vertices_for_classes
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), <<~RUBY)
            class Greeter
            end
          RUBY

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          ranges = lines.select { |line| line["label"] == "range" }

          refute_empty(ranges)
          class_range = ranges.first
          assert_equal(0, class_range.dig("start", "line"))
          assert_equal(0, class_range.dig("start", "character"))
        end
      end

      #: -> void
      def test_generates_hover_results_for_methods
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

          lines = output.string.lines.map { |line| JSON.parse(line) }
          hover_results = lines.select { |line| line["label"] == "hoverResult" }

          # Should have hover results for both class and method
          assert(hover_results.length >= 2)

          # Find the hover result for the greet method
          method_hover = hover_results.find do |hover|
            hover.dig("result", "contents", "value")&.include?("def greet")
          end

          refute_nil(method_hover)
          assert_match(/Says hello/, method_hover.dig("result", "contents", "value"))
        end
      end

      #: -> void
      def test_generates_definition_results
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          definition_results = lines.select { |line| line["label"] == "definitionResult" }

          refute_empty(definition_results)
        end
      end

      #: -> void
      def test_generates_contains_edges
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          contains_edges = lines.select { |line| line["label"] == "contains" }

          refute_empty(contains_edges)
          contains_edge = contains_edges.first
          assert_equal("edge", contains_edge["type"])
          assert(contains_edge["inVs"].is_a?(Array))
        end
      end

      #: -> void
      def test_generates_next_edges
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          next_edges = lines.select { |line| line["label"] == "next" }

          refute_empty(next_edges)
          next_edge = next_edges.first
          assert_equal("edge", next_edge["type"])
          refute_nil(next_edge["outV"])
          refute_nil(next_edge["inV"])
        end
      end

      #: -> void
      def test_excludes_dependencies_by_default
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output, nil, include_dependencies: false)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          documents = lines.select { |line| line["label"] == "document" }

          # Should only have our example.rb, not any gems
          assert_equal(1, documents.length)
          assert_match(/example\.rb$/, documents.first["uri"])
        end
      end

      #: -> void
      def test_generates_result_sets
        with_temp_workspace do |workspace_path|
          File.write(File.join(workspace_path, "example.rb"), "class Foo; end")

          output = StringIO.new
          generator = Generator.new(workspace_path, output)
          generator.generate

          lines = output.string.lines.map { |line| JSON.parse(line) }
          result_sets = lines.select { |line| line["label"] == "resultSet" }

          refute_empty(result_sets)
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
