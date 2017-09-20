# Pathway

[![Gem Version](https://badge.fury.io/rb/pathway.svg)](https://badge.fury.io/rb/pathway)
[![CircleCI](https://circleci.com/gh/pabloh/pathway/tree/master.svg?style=shield)](https://circleci.com/gh/pabloh/pathway/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/pabloh/pathway/badge.svg?branch=master)](https://coveralls.io/github/pabloh/pathway?branch=master)

Pathway allows you to encapsulate your app's business logic into operation objects (also known as application services on the DDD lingo).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pathway'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pathway

## Introduction

## Usage

### Core API and concepts

#### Function objects (`call` methods)
#### Steps
##### Succesful
##### Failed
#### Operation result
#### Initialization and context
#### Execution process state
#### Result value
#### Alternative invocation syntaxes and pattern matching DSL

### Plugins
#### Plugin architecture

#### `SimpleAuth` plugin
#### `DryValidation` plugin
#### `SequelModels` plugin
#### `Responder` plugin

### Testing tools
#### Rspec config
#### Rspec matchers

## Best practices
### Operation object design and organization
### Testing recomendations

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pabloh/pathway.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
