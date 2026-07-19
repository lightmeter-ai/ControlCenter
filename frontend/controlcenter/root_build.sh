#!/bin/sh

set -e

cd ./frontend/controlcenter
npm run build -- --dest ../../www ./src/main.js
