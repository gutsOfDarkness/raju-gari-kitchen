#!/bin/bash

# Install Flutter
if [ -d "flutter" ]; then
  cd flutter
  git pull
  cd ..
else
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support
flutter config --enable-web

# Build the web app
# You can add --dart-define args here if needed, e.g. --dart-define=API_URL=$API_URL
flutter build web --release
