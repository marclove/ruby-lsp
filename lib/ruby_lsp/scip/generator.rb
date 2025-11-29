# typed: strict
# frozen_string_literal: true

module RubyLsp
  module SCIP
    # Generates SCIP output for a Ruby project by leveraging the existing RubyIndexer.
    # SCIP (Source Code Intelligence Protocol) is a protobuf format used by Sourcegraph
    # for code intelligence features like definitions, references, and hover documentation.
    class Generator
      #: String
      attr_reader :workspace_path

      #: (String workspace_path, ?(IO | StringIO) output, ?URI::Generic? project_root, ?include_dependencies: bool) -> void
      def initialize(workspace_path, output = $stdout, project_root = nil, include_dependencies: false)
        @workspace_path = workspace_path
        @output = output #: (IO | StringIO)
        @project_root = project_root || URI::Generic.from_path(path: workspace_path) #: URI::Generic
        @index = RubyIndexer::Index.new #: RubyIndexer::Index
        @include_dependencies = include_dependencies #: bool
        @local_symbol_counter = 0 #: Integer
      end

      # Generates SCIP protobuf output for the entire workspace
      #: -> void
      def generate
        # Configure and run the indexer
        @index.configuration.workspace_path = @workspace_path
        uris = collect_indexable_uris

        # Build all documents
        documents = [] #: Array[untyped]
        uris.each do |uri|
          document = process_file(uri)
          documents << document if document
        end

        # Build the final SCIP index
        scip_index = Proto::Index.new(
          metadata: build_metadata,
          documents: documents,
        )

        # Write protobuf binary output
        @output.binmode if @output.respond_to?(:binmode)
        @output.write(Proto::Index.encode(scip_index))
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

      # Builds the SCIP metadata protobuf message
      #: -> untyped
      def build_metadata
        Proto::Metadata.new(
          version: :UnspecifiedProtocolVersion,
          tool_info: Proto::ToolInfo.new(
            name: "ruby-lsp",
            version: RubyLsp::VERSION,
          ),
          project_root: "file://#{@workspace_path}",
          text_document_encoding: :UTF8,
        )
      end

      # Generates the next local symbol ID
      #: -> String
      def next_local_symbol
        @local_symbol_counter += 1
        "local #{@local_symbol_counter}"
      end

      # Processes a single file and returns its SCIP document
      #: (URI::Generic uri) -> untyped
      def process_file(uri)
        path = uri.full_path
        return unless path && File.exist?(path)

        # Read and parse the file
        source = File.read(path)
        @index.index_single(uri, source)

        # Get all entries for this document
        entries = @index.entries_for(uri.to_s)
        return unless entries

        # Build occurrences and symbols
        occurrences = [] #: Array[untyped]
        symbols = [] #: Array[untyped]

        entries.each do |entry|
          symbol_string = build_symbol_string(entry)
          occurrence = build_occurrence(entry, symbol_string)
          occurrences << occurrence if occurrence

          symbol_info = build_symbol_information(entry, symbol_string)
          symbols << symbol_info if symbol_info
        end

        # Calculate relative path from workspace root
        relative_path = path.delete_prefix(@workspace_path).delete_prefix("/")

        Proto::Document.new(
          language: "Ruby",
          relative_path: relative_path,
          occurrences: occurrences,
          symbols: symbols,
          position_encoding: :UTF16CodeUnitOffsetFromLineStart,
        )
      end

      # Builds a SCIP symbol string for an entry
      # Format: scheme ' ' package ' ' descriptors
      #: (RubyIndexer::Entry entry) -> String
      def build_symbol_string(entry)
        # Build the symbol path based on the entry's nesting
        name = entry.name
        parts = name.split("::")

        # Build descriptors
        descriptors = parts.map.with_index do |part, index|
          if index == parts.length - 1
            # Last part - determine suffix based on entry type
            suffix = symbol_suffix(entry)
            "#{escape_identifier(part)}#{suffix}"
          else
            # Namespace part
            "#{escape_identifier(part)}/"
          end
        end

        "scip-ruby gem . . #{descriptors.join("")}"
      end

      # Determines the descriptor suffix for an entry
      #: (RubyIndexer::Entry entry) -> String
      def symbol_suffix(entry)
        case entry
        when RubyIndexer::Entry::Method
          "()"
        when RubyIndexer::Entry::Class, RubyIndexer::Entry::Module
          "#"
        when RubyIndexer::Entry::Constant
          "."
        when RubyIndexer::Entry::Accessor
          "()"
        else
          "."
        end
      end

      # Escapes an identifier for use in a SCIP symbol
      #: (String identifier) -> String
      def escape_identifier(identifier)
        # Simple identifiers can be used as-is
        if identifier.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          identifier
        else
          # Escape with backticks, doubling any internal backticks
          "`#{identifier.gsub("`", "``")}`"
        end
      end

      # Builds a SCIP occurrence protobuf message for an entry
      #: (RubyIndexer::Entry entry, String symbol) -> untyped
      def build_occurrence(entry, symbol)
        location = entry.location

        # SCIP uses 0-based line numbers and half-open ranges
        # Range format: [startLine, startCharacter, endLine, endCharacter] or
        #               [startLine, startCharacter, endCharacter] if same line
        start_line = location.start_line - 1
        end_line = location.end_line - 1

        range = if start_line == end_line
          [start_line, location.start_column, location.end_column]
        else
          [start_line, location.start_column, end_line, location.end_column]
        end

        # Build occurrence with definition role
        Proto::Occurrence.new(
          range: range,
          symbol: symbol,
          symbol_roles: symbol_roles(entry),
          syntax_kind: syntax_kind(entry),
        )
      end

      # Determines the symbol roles for an entry
      # Symbol roles are a bitset where bit 0 (value 1) means Definition
      #: (RubyIndexer::Entry entry) -> Integer
      def symbol_roles(entry)
        # All entries from the indexer are definitions
        case entry
        when RubyIndexer::Entry::Namespace, RubyIndexer::Entry::Method,
             RubyIndexer::Entry::Constant, RubyIndexer::Entry::Accessor
          1 # Definition
        else
          0
        end
      end

      # Determines the SCIP syntax kind for an entry
      #: (RubyIndexer::Entry entry) -> Symbol
      def syntax_kind(entry)
        case entry
        when RubyIndexer::Entry::Method
          :IdentifierFunction
        when RubyIndexer::Entry::Class
          :IdentifierType
        when RubyIndexer::Entry::Module
          :IdentifierNamespace
        when RubyIndexer::Entry::Constant
          :IdentifierConstant
        when RubyIndexer::Entry::Accessor
          :IdentifierFunction
        else
          :UnspecifiedSyntaxKind
        end
      end

      # Builds symbol information protobuf message for an entry
      #: (RubyIndexer::Entry entry, String symbol) -> untyped
      def build_symbol_information(entry, symbol)
        return unless definition_entry?(entry)

        docs = generate_documentation(entry)
        documentation = docs ? [docs] : []

        Proto::SymbolInformation.new(
          symbol: symbol,
          kind: symbol_kind(entry),
          documentation: documentation,
          display_name: entry.name.split("::").last || entry.name,
        )
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

      # Determines the SCIP symbol kind for an entry
      #: (RubyIndexer::Entry entry) -> Symbol
      def symbol_kind(entry)
        case entry
        when RubyIndexer::Entry::Method
          :Method
        when RubyIndexer::Entry::Class
          :Class
        when RubyIndexer::Entry::Module
          :Module
        when RubyIndexer::Entry::Constant
          :Constant
        when RubyIndexer::Entry::Accessor
          :Accessor
        else
          :UnspecifiedKind
        end
      end

      # Generates documentation for an entry
      #: (RubyIndexer::Entry entry) -> String?
      def generate_documentation(entry)
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
