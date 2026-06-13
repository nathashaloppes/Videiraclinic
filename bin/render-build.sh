#!/usr/bin/env bash
# Build script usado pelo Render (Web Service Ruby).
# Instala gems e precompila assets (Tailwind + importmap).
# As migrations rodam no preDeployCommand do render.yaml, não aqui.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
