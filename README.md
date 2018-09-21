# BHT EMR API

## Requirements

The following are required to run the API:

- Ruby 2.5+
- Rails 5.2
- MySQL 5.5+
- DDE3 - Grab it from [here](https://github.com/BaobabHealthTrust/Demographics-Data-Exchange)

In addition to the requirements above, you need the following for development.

- [Postman](https://www.getpostman.com) - Used for editing documentation
- [Postmanerator](https://github.com/aubm/postmanerator) - Used for building the documentation

## Setting up

All the operations below assume your current working directory is the
project directory. Navigate to that if you are some place else.

### Configuration

#### Database

The API uses an [Openmrs 1.7](https://openmrs.org/2010/11/openmrs-1-7-now-available/)
compatible database as a base for its own database. Grab the schema and
initialise your database. If you have an ART database schema
dump available you can (should) use that. The API was designed to hook
into an already existing database.

Copy the configuration file from `config/database.yml.example` to
`config/database.yml`. Edit the new file to point to your database.

```sh
$ cp config/database.yml.example config/database.yml
...
$ vim config/database.yml   # Edit configuration
...
```
### Setting up rails

Install the required gems like so:

```sh
bundle install
```

With that done you can run the following and test your API by
hitting `localhost:3000` in your browser. If you are greeted
by errors that is your problem, fix them before proceeding.

```sh
bin/rails server
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

### Setting up documentation tools

If you need to build the documentation then you have to set up postman and
postmanerator. Set up postman by following the instructions provided
[here](https://www.getpostman.com). For postmanerator grab a binary for
your operating system from [here](https://github.com/aubm/postmanerator/releases).

## Running the API

You can do the following (don't run it like this in production):

```sh
bin/rails server
```

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


## Running the test suite

As simple as running `bin/rspec` in the project directory.
