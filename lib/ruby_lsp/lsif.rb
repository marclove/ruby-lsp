# typed: strict
# frozen_string_literal: true

require "ruby_lsp/lsif/generator"

module RubyLsp
  # LSIF (Language Server Index Format) support for Ruby LSP.
  # LSIF allows pre-computing code navigation data for offline use.
  module LSIF
    # LSIF version this implementation follows
    VERSION = "0.6.0"

    # Protocol version
    POSITION_ENCODING = "utf-16"
  end
end
