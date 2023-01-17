#!/bin/bash

set -xe

bundle check > /dev/null 2>&1 || bundle install -j$(nproc)

exec $@
