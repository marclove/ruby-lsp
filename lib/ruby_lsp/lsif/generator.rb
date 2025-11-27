# typed: strict
# frozen_string_literal: true

module RubyLsp
  module LSIF
    # Generates LSIF output for a Ruby project by leveraging the existing RubyIndexer.
    # LSIF is a JSON graph format with vertices and edges that capture code navigation
    # information like definitions, references, and hover documentation.
    class Generator
      #: String
      attr_reader :workspace_path

      #: (String workspace_path, ?(IO | StringIO) output, ?URI::Generic? project_root, ?include_dependencies: bool) -> void
      def initialize(workspace_path, output = $stdout, project_root = nil, include_dependencies: false)
        @workspace_path = workspace_path
        @output = output #: (IO | StringIO)
        @id_counter = 0 #: Integer
        @project_root = project_root || URI::Generic.from_path(path: workspace_path) #: URI::Generic
        @index = RubyIndexer::Index.new #: RubyIndexer::Index
        @document_ids = {} #: Hash[String, Integer]
        @range_to_result_set = {} #: Hash[String, Integer]
        @definition_result_ids = {} #: Hash[String, Integer]
        @reference_result_ids = {} #: Hash[String, Integer]
        @hover_result_ids = {} #: Hash[String, Integer]
        @include_dependencies = include_dependencies #: bool
      end

      # Generates LSIF output for the entire workspace
      #: -> void
      def generate
        emit_metadata
        project_id = emit_project

        # Configure and run the indexer
        @index.configuration.workspace_path = @workspace_path
        uris = collect_indexable_uris

        # Index all files and emit LSIF data
        uris.each do |uri|
          process_file(uri, project_id)
        end
      end

      private

      # Collects the URIs to be indexed. If not including dependencies,
      # only files within the workspace directory are included.
      #: -> Array[URI::Generic]
      def collect_indexable_uris
        uris = @index.configuration.indexable_uris

        unless @include_dependencies
          # Filter to only files within the workspace
          uris.select! do |uri|
            path = uri.full_path
            path&.start_with?(@workspace_path)
          end
        end

        uris
      end

      # Generates the next unique ID for an LSIF element
      #: -> Integer
      def next_id
        @id_counter += 1
      end

      # Emits a single LSIF element (vertex or edge) as JSON
      #: (Hash[Symbol, untyped] element) -> void
      def emit(element)
        @output.puts(JSON.generate(element))
      end

      # Emits the LSIF metadata vertex
      #: -> Integer
      def emit_metadata
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "metaData",
          version: LSIF::VERSION,
          positionEncoding: POSITION_ENCODING,
          toolInfo: {
            name: "ruby-lsp",
            version: RubyLsp::VERSION,
          },
        })
        id
      end

      # Emits the project vertex
      #: -> Integer
      def emit_project
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "project",
          kind: "ruby",
        })
        id
      end

      # Emits a document vertex and returns its ID
      #: (URI::Generic uri) -> Integer
      def emit_document(uri)
        id = next_id
        uri_string = uri.to_s

        emit({
          id: id,
          type: "vertex",
          label: "document",
          uri: uri_string,
          languageId: "ruby",
        })

        @document_ids[uri_string] = id
        id
      end

      # Emits a range vertex for a location
      #: (RubyIndexer::Location location) -> Integer
      def emit_range(location)
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "range",
          start: {
            line: location.start_line - 1, # LSIF uses 0-based lines
            character: location.start_column,
          },
          end: {
            line: location.end_line - 1,
            character: location.end_column,
          },
        })
        id
      end

      # Emits a result set vertex
      #: -> Integer
      def emit_result_set
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "resultSet",
        })
        id
      end

      # Emits a hover result vertex
      #: (String content) -> Integer
      def emit_hover_result(content)
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "hoverResult",
          result: {
            contents: {
              kind: "markdown",
              value: content,
            },
          },
        })
        id
      end

      # Emits a definition result vertex
      #: -> Integer
      def emit_definition_result
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "definitionResult",
        })
        id
      end

      # Emits a reference result vertex
      #: -> Integer
      def emit_reference_result
        id = next_id
        emit({
          id: id,
          type: "vertex",
          label: "referenceResult",
        })
        id
      end

      # Emits an edge between vertices
      #: (String label, Integer out_v, (Integer | Array[Integer]) in_v) -> Integer
      def emit_edge(label, out_v, in_v)
        id = next_id
        edge = {
          id: id,
          type: "edge",
          label: label,
          outV: out_v,
        }

        if in_v.is_a?(Array)
          edge[:inVs] = in_v
        else
          edge[:inV] = in_v
        end

        emit(edge)
        id
      end

      # Emits a contains edge
      #: (Integer out_v, Array[Integer] in_vs) -> Integer
      def emit_contains(out_v, in_vs)
        emit_edge("contains", out_v, in_vs)
      end

      # Emits a textDocument/definition edge
      #: (Integer out_v, Integer in_v) -> Integer
      def emit_definition_edge(out_v, in_v)
        emit_edge("textDocument/definition", out_v, in_v)
      end

      # Emits a textDocument/references edge
      #: (Integer out_v, Integer in_v) -> Integer
      def emit_references_edge(out_v, in_v)
        emit_edge("textDocument/references", out_v, in_v)
      end

      # Emits a textDocument/hover edge
      #: (Integer out_v, Integer in_v) -> Integer
      def emit_hover_edge(out_v, in_v)
        emit_edge("textDocument/hover", out_v, in_v)
      end

      # Emits a next edge (range to resultSet)
      #: (Integer out_v, Integer in_v) -> Integer
      def emit_next_edge(out_v, in_v)
        emit_edge("next", out_v, in_v)
      end

      # Emits an item edge for references
      #: (Integer out_v, Array[Integer] in_vs, Integer document, ?String? property) -> Integer
      def emit_item_edge(out_v, in_vs, document, property = nil)
        id = next_id
        edge = {
          id: id,
          type: "edge",
          label: "item",
          outV: out_v,
          inVs: in_vs,
          document: document,
        }
        edge[:property] = property if property
        emit(edge)
        id
      end

      # Processes a single file and emits its LSIF data
      #: (URI::Generic uri, Integer project_id) -> void
      def process_file(uri, project_id)
        path = uri.full_path
        return unless path && File.exist?(path)

        # Read and parse the file
        source = File.read(path)
        @index.index_single(uri, source)

        # Emit document vertex
        document_id = emit_document(uri)
        range_ids = [] #: Array[Integer]

        # Get all entries for this document
        entries = @index.entries_for(uri.to_s)
        return unless entries

        # Process each entry
        entries.each do |entry|
          range_id = process_entry(entry, document_id)
          range_ids << range_id if range_id
        end

        # Emit contains edge for all ranges in this document
        emit_contains(document_id, range_ids) if range_ids.any?
      end

      # Processes a single index entry and emits its LSIF data
      #: (RubyIndexer::Entry entry, Integer document_id) -> Integer?
      def process_entry(entry, document_id)
        # Emit range for the entry
        range_id = emit_range(entry.location)

        # Create a result set for this entry
        result_set_id = emit_result_set
        emit_next_edge(range_id, result_set_id)

        # Generate hover content
        hover_content = generate_hover_content(entry)
        if hover_content
          hover_id = emit_hover_result(hover_content)
          emit_hover_edge(result_set_id, hover_id)
        end

        # For definitions, emit definition result
        if definition_entry?(entry)
          definition_result_id = emit_definition_result
          emit_definition_edge(result_set_id, definition_result_id)
          emit_item_edge(definition_result_id, [range_id], document_id, "definitions")

          # Store for later reference linking
          @definition_result_ids[entry.name] = definition_result_id
          @range_to_result_set[entry.name] = result_set_id
        end

        range_id
      end

      # Checks if an entry is a definition
      #: (RubyIndexer::Entry entry) -> bool
      def definition_entry?(entry)
        case entry
        when RubyIndexer::Entry::Namespace, RubyIndexer::Entry::Method,
             RubyIndexer::Entry::Constant, RubyIndexer::Entry::Accessor
          true
        else
          false
        end
      end

      # Generates hover content for an entry
      #: (RubyIndexer::Entry entry) -> String?
      def generate_hover_content(entry)
        case entry
        when RubyIndexer::Entry::Method
          signatures = entry.signatures.map { |sig| "(#{sig.format})" }.join("\n")
          content = "```ruby\ndef #{entry.name}#{signatures.empty? ? "" : signatures}\n```"
          content += "\n\n#{entry.comments}" unless entry.comments.empty?
          content
        when RubyIndexer::Entry::Class
          content = "```ruby\nclass #{entry.name}"
          content += " < #{entry.parent_class}" if entry.parent_class
          content += "\n```"
          content += "\n\n#{entry.comments}" unless entry.comments.empty?
          content
        when RubyIndexer::Entry::Module
          content = "```ruby\nmodule #{entry.name}\n```"
          content += "\n\n#{entry.comments}" unless entry.comments.empty?
          content
        when RubyIndexer::Entry::Constant
          content = "```ruby\n#{entry.name}\n```"
          content += "\n\n#{entry.comments}" unless entry.comments.empty?
          content
        end
      end
    end
  end
end
