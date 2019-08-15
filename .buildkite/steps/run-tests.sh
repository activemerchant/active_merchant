#!/usr/bin/env bash

set -euo pipefail

readonly RAILS_VERSIONS=(41 42 50 51)
readonly RUBY_VERSIONS=(2.3.8 2.3.8 2.5 2.5)
readonly CURRENT_JOB_IDX=`expr ${BUILDKITE_PARALLEL_JOB} + 1`
readonly RAILS_VERSION=${RAILS_VERSIONS[$CURRENT_JOB_IDX]}
readonly RUBY_VERSION=${RUBY_VERSIONS[$CURRENT_JOB_IDX]}

echo ":llama: Testing with :ruby: ${RUBY_VERSION} | :rails: ${RAILS_VERSION}"

docker run -it --rm -v "$PWD":/usr/src -w /usr/src ruby:${RUBY_VERSION}-stretch sh -c "bundle check --path=vendor/bundle_${RAILS_VERSION} \
    --gemfile Gemfile.rails${RAILS_VERSION} || bundle install --jobs=4 --retry=3 --gemfile Gemfile.rails${RAILS_VERSION} --path=vendor/bundle_${RAILS_VERSION} ; \
    BUNDLE_GEMFILE=Gemfile.rails${RAILS_VERSION} bundle exec rake test:units"
