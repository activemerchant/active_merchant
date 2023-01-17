FROM ruby:2.7.7

ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

WORKDIR /var/app

COPY . .

RUN gem install bundler && \
    bundle config set https://rubygems.pkg.github.com/paywith $GITHUB_USERNAME:$GITHUB_TOKEN && \
    bundle install -j$(nproc)

ENTRYPOINT [ "./entrypoint.sh" ]