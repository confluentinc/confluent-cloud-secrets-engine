#!/bin/bash

# Change to the astrodocs directory
cd astrodocs

# Install dependencies (this is only needed the first time)
npm i

# Build and publish the documentation to GitHub Pages
npm run gh-pages