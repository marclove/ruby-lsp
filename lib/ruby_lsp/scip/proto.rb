# typed: strict
# frozen_string_literal: true

# SCIP (Source Code Intelligence Protocol) protobuf message definitions.
# Generated from https://github.com/sourcegraph/scip/blob/main/scip.proto
#
# This uses manual protobuf encoding to avoid external dependencies.
# We implement the minimal subset needed for the SCIP generator.

module RubyLsp
  module SCIP
    module Proto
      # Enum modules for SCIP protocol
      module ProtocolVersion
        UNSPECIFIED = 0
      end

      module TextEncoding
        UNSPECIFIED = 0
        UTF8 = 1
        UTF16 = 2
      end

      module PositionEncoding
        UNSPECIFIED = 0
        UTF8_CODE_UNIT = 1
        UTF16_CODE_UNIT = 2
        UTF32_CODE_UNIT = 3
      end

      module SyntaxKind
        UNSPECIFIED = 0
        COMMENT = 1
        PUNCTUATION_DELIMITER = 2
        PUNCTUATION_BRACKET = 3
        KEYWORD = 4
        IDENTIFIER_OPERATOR = 5
        IDENTIFIER = 6
        IDENTIFIER_BUILTIN = 7
        IDENTIFIER_NULL = 8
        IDENTIFIER_CONSTANT = 9
        IDENTIFIER_MUTABLE_GLOBAL = 10
        IDENTIFIER_PARAMETER = 11
        IDENTIFIER_LOCAL = 12
        IDENTIFIER_SHADOWED = 13
        IDENTIFIER_NAMESPACE = 14
        IDENTIFIER_FUNCTION = 15
        IDENTIFIER_FUNCTION_DEFINITION = 16
        IDENTIFIER_MACRO = 17
        IDENTIFIER_MACRO_DEFINITION = 18
        IDENTIFIER_TYPE = 19
        IDENTIFIER_BUILTIN_TYPE = 20
        IDENTIFIER_ATTRIBUTE = 21
      end

      module SymbolKind
        UNSPECIFIED = 0
        CLASS = 7
        CONSTANT = 8
        METHOD = 26
        MODULE = 29
        ACCESSOR = 72
      end

      # Simple protobuf encoder for writing varint and length-delimited fields
      class Encoder
        #: () -> void
        def initialize
          @buffer = +"" #: String
          @buffer.force_encoding(Encoding::BINARY)
        end

        #: () -> String
        def to_s
          @buffer
        end

        # Write a varint (variable-length integer)
        #: (Integer value) -> void
        def write_varint(value)
          loop do
            byte = value & 0x7F
            value >>= 7
            if value == 0
              @buffer << byte.chr
              break
            else
              @buffer << (byte | 0x80).chr
            end
          end
        end

        # Write a tag (field_number << 3 | wire_type)
        #: (Integer field_number, Integer wire_type) -> void
        def write_tag(field_number, wire_type)
          write_varint((field_number << 3) | wire_type)
        end

        # Write a string (length-delimited)
        #: (Integer field_number, String value) -> void
        def write_string(field_number, value)
          return if value.empty?

          write_tag(field_number, 2) # wire_type 2 = length-delimited
          bytes = value.encode(Encoding::UTF_8)
          write_varint(bytes.bytesize)
          @buffer << bytes
        end

        # Write an embedded message (length-delimited)
        #: (Integer field_number, String message_bytes) -> void
        def write_message(field_number, message_bytes)
          return if message_bytes.empty?

          write_tag(field_number, 2)
          write_varint(message_bytes.bytesize)
          @buffer << message_bytes
        end

        # Write a varint field
        #: (Integer field_number, Integer value) -> void
        def write_int32(field_number, value)
          return if value == 0

          write_tag(field_number, 0) # wire_type 0 = varint
          write_varint(value)
        end

        # Write a repeated int32 (packed)
        #: (Integer field_number, Array[Integer] values) -> void
        def write_packed_int32(field_number, values)
          return if values.empty?

          # Encode all values into a temporary buffer
          packed = Encoder.new
          values.each { |v| packed.write_varint(v) }

          write_tag(field_number, 2) # length-delimited
          write_varint(packed.to_s.bytesize)
          @buffer << packed.to_s
        end

        # Write a repeated string field
        #: (Integer field_number, Array[String] values) -> void
        def write_repeated_string(field_number, values)
          values.each { |v| write_string(field_number, v) }
        end

        # Write a repeated message field
        #: (Integer field_number, Array[String] messages) -> void
        def write_repeated_message(field_number, messages)
          messages.each { |m| write_message(field_number, m) }
        end
      end

      # ToolInfo message
      class ToolInfo
        #: String
        attr_accessor :name
        #: String
        attr_accessor :version
        #: Array[String]
        attr_accessor :arguments

        #: (?name: String, ?version: String, ?arguments: Array[String]) -> void
        def initialize(name: "", version: "", arguments: [])
          @name = name
          @version = version
          @arguments = arguments
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_string(1, @name)
          encoder.write_string(2, @version)
          encoder.write_repeated_string(3, @arguments)
          encoder.to_s
        end
      end

      # Metadata message
      class Metadata
        #: Integer
        attr_accessor :version
        #: ToolInfo?
        attr_accessor :tool_info
        #: String
        attr_accessor :project_root
        #: Integer
        attr_accessor :text_document_encoding

        #: (?version: Integer, ?tool_info: ToolInfo?, ?project_root: String, ?text_document_encoding: Integer) -> void
        def initialize(version: 0, tool_info: nil, project_root: "", text_document_encoding: 0)
          @version = version
          @tool_info = tool_info
          @project_root = project_root
          @text_document_encoding = text_document_encoding
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_int32(1, @version)
          encoder.write_message(2, @tool_info&.encode || "")
          encoder.write_string(3, @project_root)
          encoder.write_int32(4, @text_document_encoding)
          encoder.to_s
        end
      end

      # Occurrence message
      class Occurrence
        #: Array[Integer]
        attr_accessor :range
        #: String
        attr_accessor :symbol
        #: Integer
        attr_accessor :symbol_roles
        #: Array[String]
        attr_accessor :override_documentation
        #: Integer
        attr_accessor :syntax_kind

        #: (?range: Array[Integer], ?symbol: String, ?symbol_roles: Integer, ?override_documentation: Array[String], ?syntax_kind: Integer) -> void
        def initialize(range: [], symbol: "", symbol_roles: 0, override_documentation: [], syntax_kind: 0)
          @range = range
          @symbol = symbol
          @symbol_roles = symbol_roles
          @override_documentation = override_documentation
          @syntax_kind = syntax_kind
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_packed_int32(1, @range)
          encoder.write_string(2, @symbol)
          encoder.write_int32(3, @symbol_roles)
          encoder.write_repeated_string(4, @override_documentation)
          encoder.write_int32(5, @syntax_kind)
          encoder.to_s
        end
      end

      # SymbolInformation message
      class SymbolInformation
        #: String
        attr_accessor :symbol
        #: Array[String]
        attr_accessor :documentation
        #: Integer
        attr_accessor :kind
        #: String
        attr_accessor :display_name

        #: (?symbol: String, ?documentation: Array[String], ?kind: Integer, ?display_name: String) -> void
        def initialize(symbol: "", documentation: [], kind: 0, display_name: "")
          @symbol = symbol
          @documentation = documentation
          @kind = kind
          @display_name = display_name
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_string(1, @symbol)
          encoder.write_repeated_string(3, @documentation)
          encoder.write_int32(5, @kind)
          encoder.write_string(6, @display_name)
          encoder.to_s
        end
      end

      # Document message
      class Document
        #: String
        attr_accessor :language
        #: String
        attr_accessor :relative_path
        #: Array[Occurrence]
        attr_accessor :occurrences
        #: Array[SymbolInformation]
        attr_accessor :symbols
        #: Integer
        attr_accessor :position_encoding

        #: (?language: String, ?relative_path: String, ?occurrences: Array[Occurrence], ?symbols: Array[SymbolInformation], ?position_encoding: Integer) -> void
        def initialize(language: "", relative_path: "", occurrences: [], symbols: [], position_encoding: 0)
          @language = language
          @relative_path = relative_path
          @occurrences = occurrences
          @symbols = symbols
          @position_encoding = position_encoding
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_string(4, @language)
          encoder.write_string(1, @relative_path)
          encoder.write_repeated_message(2, @occurrences.map(&:encode))
          encoder.write_repeated_message(3, @symbols.map(&:encode))
          encoder.write_int32(6, @position_encoding)
          encoder.to_s
        end
      end

      # Index message (top-level)
      class Index
        #: Metadata?
        attr_accessor :metadata
        #: Array[Document]
        attr_accessor :documents
        #: Array[SymbolInformation]
        attr_accessor :external_symbols

        #: (?metadata: Metadata?, ?documents: Array[Document], ?external_symbols: Array[SymbolInformation]) -> void
        def initialize(metadata: nil, documents: [], external_symbols: [])
          @metadata = metadata
          @documents = documents
          @external_symbols = external_symbols
        end

        #: () -> String
        def encode
          encoder = Encoder.new
          encoder.write_message(1, @metadata&.encode || "")
          encoder.write_repeated_message(2, @documents.map(&:encode))
          encoder.write_repeated_message(3, @external_symbols.map(&:encode))
          encoder.to_s
        end
      end
    end
  end
end
