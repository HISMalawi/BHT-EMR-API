# Use an official Ruby runtime as a parent image
FROM ruby:3.2.0

# Install dependencies
RUN apt-get update && \
    apt-get install git -y && \
    apt-get install curl -y
# Remove the build-essential, libpq-dev, and mysql-client packages
# RUN apt-get remove build-essential libpq-dev mysql-client -y

# Set the working directory to /api
WORKDIR /api

# Copy the Gemfile and Gemfile.lock from the app directory into the container
COPY Gemfile Gemfile.lock /api/

# Run bundle install to install Ruby dependencies
RUN gem install bundler

# Install any needed packages specified in the Gemfile
RUN bundle install

# Copy the rest of the application code into the container
COPY . /api/

# Expose port 3000 to the Docker host, so we can access it from the outside
EXPOSE 3000

# Start the Rails server when the container starts, binding it to port 3000
CMD ["rails", "server", "-b", "0.0.0.0:3000"]