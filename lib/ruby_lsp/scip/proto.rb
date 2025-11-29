# typed: ignore
# frozen_string_literal: true

require "google/protobuf"
require "google/protobuf/descriptor_pb"

# SCIP (Source Code Intelligence Protocol) protobuf message definitions.
# Generated from https://github.com/sourcegraph/scip/blob/main/scip.proto
#
# This loads the pre-compiled protobuf descriptor and registers it with
# the google-protobuf library.

# Load and register the SCIP protobuf descriptor
descriptor_path = File.expand_path("scip_pb.binpb", __dir__)
descriptor_data = File.binread(descriptor_path)

file_desc_set = Google::Protobuf::FileDescriptorSet.decode(descriptor_data)
file_desc_set.file.each do |file_proto|
  serialized = Google::Protobuf::FileDescriptorProto.encode(file_proto)
  Google::Protobuf::DescriptorPool.generated_pool.add_serialized_file(serialized)
end

module RubyLsp
  module SCIP
    # SCIP protobuf message classes from google-protobuf
    module Proto
      Index = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Index").msgclass
      Metadata = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Metadata").msgclass
      ToolInfo = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.ToolInfo").msgclass
      Document = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Document").msgclass
      Symbol = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Symbol").msgclass
      Package = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Package").msgclass
      Descriptor = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Descriptor").msgclass
      SymbolInformation = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.SymbolInformation").msgclass
      Relationship = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Relationship").msgclass
      Occurrence = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Occurrence").msgclass
      Diagnostic = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Diagnostic").msgclass

      # Enums
      ProtocolVersion = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.ProtocolVersion").enummodule
      TextEncoding = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.TextEncoding").enummodule
      PositionEncoding = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.PositionEncoding").enummodule
      SymbolRole = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.SymbolRole").enummodule
      SyntaxKind = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.SyntaxKind").enummodule
      Severity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Severity").enummodule
      DiagnosticTag = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.DiagnosticTag").enummodule
      Language = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Language").enummodule
      DescriptorSuffix = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.Descriptor.Suffix").enummodule
      SymbolInformationKind = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("scip.SymbolInformation.Kind").enummodule
    end
  end
end
