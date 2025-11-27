# typed: strict
# frozen_string_literal: true

require "ruby_lsp/scip/generator"

module RubyLsp
  # SCIP (Source Code Intelligence Protocol) support for Ruby LSP.
  # SCIP is a code intelligence format used by Sourcegraph for cross-repository
  # navigation and code intelligence features.
  module SCIP
    # SCIP protocol version
    PROTOCOL_VERSION = 0

    # Position encoding - UTF-16 code units (matching LSP)
    POSITION_ENCODING = "UTF16CodeUnitOffsetFromLineStart"
  end
end
