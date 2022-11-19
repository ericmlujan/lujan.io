FROM ruby:3.1.2

# Setup application directory
WORKDIR /usr/src/app

# Install application dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENV LANG="C.UTF-8"
ENV RACK_ENV="production"

# Run server on port 3000
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-p", "3000"]
