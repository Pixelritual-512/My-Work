#!/bin/bash
export PATH="$HOME/.npm-global/bin:$HOME/.pub-cache/bin:$PATH"

echo "Step 1: Logging into Firebase..."
echo "If you are already logged in, this step will be quick."
firebase login

echo ""
echo "Step 2: Configuring FlutterFire..."
echo "Select your project and platforms (Android & Web) when prompted."
flutterfire configure
