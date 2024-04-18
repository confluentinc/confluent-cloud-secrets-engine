#!/bin/bash

# Change to the astrodocs directory
cd astrodocs

# Install dependencies (this is only needed the first time)
npm i

# Build the documentation
npm run build

# Preview the documentation
npm run preview