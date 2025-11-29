<p align="center">
  <img alt="Ruby LSP logo" width="200" src="vscode/icon.png" />
</p>

[![Build Status](https://github.com/Shopify/ruby-lsp/workflows/CI/badge.svg)](https://github.com/Shopify/ruby-lsp/actions/workflows/ci.yml)
[![Ruby LSP extension](https://img.shields.io/badge/VS%20Code-Ruby%20LSP-success?logo=visual-studio-code)](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp)
[![Ruby DX Slack](https://img.shields.io/badge/Slack-Ruby%20DX-success?logo=slack)](https://shopify.github.io/ruby-lsp/invite)

# Ruby LSP

The Ruby LSP is an implementation of the [language server protocol](https://microsoft.github.io/language-server-protocol/)
for Ruby, used to improve rich features in editors. It is a part of a wider goal to provide a state-of-the-art
experience to Ruby developers using modern standards for cross-editor features, documentation and debugging.

Want to discuss Ruby developer experience? Consider joining the public
[Ruby DX Slack workspace](https://shopify.github.io/ruby-lsp/invite).

## Getting Started

For VS Code users, you can start by installing the [Ruby LSP extension](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp) from the VS Code marketplace.

For other editors, please refer to the [EDITORS](https://shopify.github.io/ruby-lsp/editors.html) guide.

To learn more about Ruby LSP, please refer to the official [documentation](https://shopify.github.io/ruby-lsp) for [supported features](https://shopify.github.io/ruby-lsp#features).

## LSIF Generator

Ruby LSP includes an LSIF (Language Server Index Format) generator that pre-computes code navigation data for offline use. This is useful for:

- **Code search platforms** like Sourcegraph or GitHub Code Search
- **Static documentation** with code navigation features
- **CI/CD pipelines** that need code intelligence without running a language server

### Usage

Generate LSIF output for your project:

```bash
# Basic usage - outputs to stdout
ruby-lsp-lsif

# Write output to a file
ruby-lsp-lsif -o project.lsif

# Index a specific workspace directory
ruby-lsp-lsif -w /path/to/project -o output.lsif

# Include gem dependencies in the index
ruby-lsp-lsif --include-dependencies -o output.lsif
```

The LSIF generator automatically uses the Composed Bundle mechanism to access your project's dependencies, ensuring accurate indexing. No additional setup is required - just run it in your project directory.

For more information about LSIF, see the [LSIF specification](https://microsoft.github.io/language-server-protocol/specifications/lsif/0.6.0/specification/).

#### Install Locally

This makes your fork available as the ruby-lsp gem on your system:

**Build and install your fork**

```sh
cd /workspace/ruby-lsp
gem build ruby-lsp.gemspec
gem install ruby-lsp-*.gem

# 2. Generate LSIF for the Rails app
ruby-lsp-lsif -w ../my-ruby-gem -o ../my-ruby-gem/index.lsif

# Clean up the built gem file (optional)
rm ruby-lsp-*.gem
```

The installed ruby-lsp-lsif executable will now use your fork's code.

## SCIP Generator

Ruby LSP also includes a SCIP (Source Code Intelligence Protocol) generator. SCIP is a code intelligence format used by Sourcegraph for cross-repository navigation and code intelligence features. The output is in protobuf binary format as defined by the [SCIP schema](https://github.com/sourcegraph/scip/blob/main/scip.proto).

### Usage

Generate SCIP output for your project:

```bash
# Basic usage - outputs to stdout (binary protobuf)
ruby-lsp-scip

# Write output to a file
ruby-lsp-scip -o project.scip

# Index a specific workspace directory
ruby-lsp-scip -w /path/to/project -o output.scip

# Include gem dependencies in the index
ruby-lsp-scip --include-dependencies -o output.scip
```

The SCIP generator automatically uses the Composed Bundle mechanism to access your project's dependencies, ensuring accurate indexing. No additional setup is required - just run it in your project directory.

For more information about SCIP, see the [SCIP repository](https://github.com/sourcegraph/scip).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/ruby-lsp. This project is intended to
be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor
Covenant](CODE_OF_CONDUCT.md) code of conduct.

If you wish to contribute, see [Contributing](https://shopify.github.io/ruby-lsp/contributing.html) for development instructions and check out our
[Design and roadmap](https://shopify.github.io/ruby-lsp/design-and-roadmap.html) for a list of tasks to get started.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
