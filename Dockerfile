FROM ruby:3.4.3

# Setup application directory
WORKDIR /usr/src/app

# Install application dependencies (exclude :tools group — upload scripts, not needed at runtime)
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_WITHOUT=tools
RUN bundle install

COPY . .

ENV LANG="C.UTF-8"
ENV RACK_ENV="production"

# Run server on port 3000
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-p", "3000"]
