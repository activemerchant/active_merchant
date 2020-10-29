FROM ruby:2.5.6

WORKDIR /var/app
COPY . .

RUN gem install bundler
RUN bundle install -j4