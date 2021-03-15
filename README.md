# BHT EMR API

## Requirements

The following are required to run the API:

- Ruby 2.5+
- Rails 5.2
- MySQL 5.5+

The following dependencies are also required for some operations,
however the API can do without:

- DDE3 - Grab it from [here](https://github.com/BaobabHealthTrust/Demographics-Data-Exchange)

In addition to the requirements above, you need the following for development.

- [Postman](https://www.getpostman.com) - Used for editing documentation
- [Postmanerator](https://github.com/aubm/postmanerator) - Used for building the documentation

## Setting up

All the operations below assume your current working directory is the
project directory. Navigate to that if you are some place else.

### Configuration

### Setting up rails

Install the required gems like so:

```sh
bundle install
```

#### Database

The API uses an [Openmrs 1.7](https://openmrs.org/2010/11/openmrs-1-7-now-available/)
compatible database as a base for its own database. If you have an ART database
dump available you can (and should) use that. The API was designed to hook
into an already existing database.

Copy the configuration file from `config/database.yml.example` to
`config/database.yml`. Edit the new file to point to your database.

```sh
$ cp config/database.yml.example config/database.yml
...
$ vim config/database.yml   # Edit configuration
...
```

##### Using an existing database

1. Load metadata into your mysql database as follows:

    ```bash
    cat db/sql/openmrs_metadata_1_7.sql | mysql -u <username> -p <database_name>
    ```

2. Run migrations:

    ```bash
    bin/rails db:migrate
    ```

3. Load moh regimen tables into your database:

    ```bash
    cat db/sql/add_regimens_13_and_above.sql | mysql -u <username> -p <database>
    ```
4. For TB app: Load ntp regimen tables into your database:

    ```bash
    cat db/sql/ntp_regimens.sql | mysql -u <username> -p <database>
    ```

5. Set up the test database as follows:

    ```bash
    bin/initial_database_setup.sh test mpc
    ```

6. Run the following to run tests (if all goes well you are good to go):

    ```bash
    bin/rspec
    ```

##### Using an empty database

1. Run the following commands to set up your development and test databases.

    ```bash
    bin/initial_database_setup.sh development mpc && bin/initial_database_setup.sh test mpc
    ```

2. Run test suite as follows:

    ```bash
    bin/rspec
    ```

#### DDE

- Configuration

Copy `config/application.yml.example` to `config/application.yml`. Edit all the
`dde_*` parameters to point to a running DDE instance.

```sh
$ cp config/application.yml.example config/application.yml
...
$ vim config/application.yml
...
```

- Enabling DDE

To enable DDE you have to set the global_property `dde_enabled` to 1. Global
properties can be updated through the `properties` end-point or directly in
the database on the global_property table. Below is how you can do it on
a UNIX terminal.

First log into the API:

```sh
curl -X POST -H "Content-Type: application/json" -d '{
    "username": "admin",
    "password": "test"
}' "http://127.0.0.1:3000/api/v1/auth/login"
```

The command above should give a response similar to the following:

```json
    {
        "authorization": {
            "token": "AiJViSpF3spb",
            "expiry_time": "2018-08-28T11:01:55.501+02:00"
        }
    }
```

Take token above and use it the following command as a parameter to
the Authorization header as:

```sh
curl -X POST -H "Authorization: AiJViSpF3spb" -H "Content-Type: application/json" -d '{
    "property": "dde_enabled",
    "value": "true"
}' "http://127.0.0.1:3000/api/v1/properties"
```

## Running the API

You can do the following (don't run it like this in production):

```sh
bin/rails server
```

## Raw Data Store

The BHT-EMR-API is capable of pushing data to the Raw Data Store.
More information on how to get it to do this can be found [here](./doc/rds/index.md)

## For developers

### Documentation

If you need to build the documentation then you have to set up postman and
postmanerator. Set up postman by following the instructions provided
[here](https://www.getpostman.com). For postmanerator grab a binary for
your operating system from [here](https://github.com/aubm/postmanerator/releases).
## Building the Documentation

To edit the documentation, fire up postman and then import the collection at
`doc/src/index.json`. Once done editing it in postman, export it back
as version 1 collection to the same path.

To build the documentation do the following:

```sh
postmanerator --collection=doc/src/index.json --output=public/index.html
```

A wrapper script for the above command is provided to make life easier.
Execute it like so:

```sh
bin/make_docs
```

You can view the documentation by opening `public/index.html` or hitting
`/index.html` on a running instance of the API.

## Testing

[RSpec](http://rspec.info) and [RSpec-rails](https://github.com/rspec/rspec-rails)
are used for unit/integration testing. Primarily tests are written as feature
tests for services (See coding style below), however in some cases unit tests are
done for small pieces that looks suspect.

A test database is require before anything else. Run the following to set up the
test database.

```sh
$ bin/initial_database_setup.sh test moh
...
```

WARNING: The command above will clobber the database set up for testing the
database configuration.

To run the tests, navigate to the project directory and run `bin/rspec`. You can
target a specific test by running `bin/rspec <path-to-test>`.

```sh
$ bin/rspec     # To run all tests
...
$ bin/rspec path/to/test    # To run specific test
...
```

## Coding style/standards

At a minimum try to stick to the following:

- Use 2 spaces (not tab configured to take 2 spaces) for indentation
- Methods should normally not exceed 12 lines (you can go beyond this with good reason)
- Prefer `&&/||` over `and/or`
- Error should never pass silently, if you handle an exception, log the error you just handled
- Related to the point above, avoid inline rescue statements
- Use guard statements when validating a variable, if you can't, consider moving the validation logic to a method
- Package your business logic in services where possible. These are located in `app/services` directory.
  Try to keep them [SOLID](https://en.wikipedia.org/wiki/SOLID) please.
- If you know it's a hack please leave a useful comment
- If what you wrote doesn't make sense, revise until it does else leave useful comments and a unit test
- If a file exceeds 120 lines, you better have a good reason as to why it is so
- This is Ruby, it shouldn't read like Java, see [Writing Beautiful Ruby](https://medium.com/the-renaissance-developer/idiomatic-ruby-1b5fa1445098)

See the following for more:

- [Rubocop style guide](https://github.com/rubocop-hq/ruby-style-guide)

## Useful (recommended) tools for development

- [Vscode](https://code.visualstudio.com/download) for editing
- Rubocop - you can use this to format your code and find/fix various [defect attractors](http://esr.ibiblio.org/?p=8042)
- If you use VSCode check out the following plugins [Ruby](https://marketplace.visualstudio.com/search?term=Ruby&target=VSCode), [Ruby-Rubocop](https://marketplace.visualstudio.com/search?term=Rubocop&target=VSCode&category=All%20categories&sortBy=Relevance), and [Rufo](https://marketplace.visualstudio.com/search?term=Rufo&target=VSCode&category=All%20categories&sortBy=Relevance)
