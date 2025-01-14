# Use Ruby 2.5.8 as base image
FROM ruby:2.5.8

ENV DEBIAN_FRONTEND noninteractive
ENV RAILS_ENV production

# Install essential Linux packages
RUN apt-get update -qq
RUN apt-get install -y build-essential libpq-dev postgresql-client nodejs imagemagick sudo libxss1 libappindicator1 libindicator7 unzip memcached

# Files created inside the container repect the ownership
RUN adduser --shell /bin/bash --disabled-password --gecos "" consul \
  && adduser consul sudo \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN echo 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bundle/bin"' > /etc/sudoers.d/secure_path
RUN chmod 0440 /etc/sudoers.d/secure_path

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

# Define where our application will live inside the image
ENV RAILS_ROOT /var/www/consul

# Create application home. App server will need the pids dir so just create everything in one shot
RUN mkdir -p $RAILS_ROOT/tmp/pids

# Set our working directory inside the image
WORKDIR $RAILS_ROOT

# Use the Gemfiles as Docker cache markers. Always bundle before copying app src.
# (the src likely changed and we don't want to invalidate Docker's cache too early)
# http://ilikestuffblog.com/2014/01/06/how-to-skip-bundle-install-when-deploying-a-rails-app-to-docker/
COPY Gemfile Gemfile

COPY Gemfile.lock Gemfile.lock

COPY Gemfile_custom Gemfile_custom

# Prevent bundler warnings; ensure that the bundler version executed is >= that which created Gemfile.lock
RUN gem install bundler -v 2.2.21

# Finish establishing our Ruby environment
RUN bundle install --full-index

# Install Chromium for E2E integration tests
RUN apt-get update -qq && apt-get install -y chromium

# Copy the Rails application into place
COPY . .

ENV SECRET_KEY_BASE placeholder
ENV SENDGRID_API_KEY placeholder
ENV SERVER_NAME placeholder
ENV UPLOADS_S3_BUCKET placeholder
ENV UPLOADS_S3_REGION placeholder
ENV SMTP_HOSTNAME placeholder
ENV SMTP_USERNAME placeholder
ENV SMTP_PASSWORD placeholder
ENV FQDN placeholder
ENV DOMAINPREFIX ""
ENV UPLOADS_CDN_DOMAIN placeholder

# Set the theme that will be used for the compiled assets in the next step.
ARG THEME=
ENV THEME ${THEME}

# Compiling!
RUN bundle exec rails assets:precompile

# RUN ln -sf /dev/stdout /var/www/consul/log/preproduction.log; \
#     ln -sf /dev/stdout /var/www/consul/log/production.log; \
#     ln -sf /dev/stdout /var/www/consul/log/staging.log

# Define the script we want run once the container boots
# Use the "exec" form of CMD so our script shuts down gracefully on SIGTERM (i.e. `docker stop`)
# CMD [ "config/containers/app_cmd.sh" ]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
