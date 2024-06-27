![Ruby](https://github.com/EGPAFMalawiHIS/HIS-EMR-API-Lab/workflows/Ruby/badge.svg?branch=development)
# Lab

A Rails engine for [HIS-EMR-API](https://github.com/EGPAFMalawiHIS/HIS-EMR-API)
compatible applications that provides an API for managing various lab
activities.

## Usage

The engine provides an API that provides the following functionalities:

  - Search/Retrieve test types
  - Search/Retrieve sample types for a given test
  - Order lab tests
  - Attach a result to a test

For details on how to perform these operations please see the
[API docs](https://raw.githack.com/EGPAFMalawiHIS/HIS-EMR-API-Lab/development/docs/api.html).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lab', git: 'https://github.com/EGPAFMalawiHIS/HIS-EMR-API-Lab', branch: 'development'
```

And then execute:

```bash
$ bundle install lab
```

Or install it yourself as:

```bash
$ gem install lab
```

Finally run:

```bash
$ bundle exec rails lab:install
```

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
