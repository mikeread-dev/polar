#!/bin/bash

# This script runs the timezone tests with a simulated UTC+10 timezone
# to ensure the fix works correctly

echo "Running timezone tests for UTC+10..."

# Use TZ environment variable to simulate UTC+10 timezone
# Australia/Sydney is UTC+10 (or +11 during daylight savings)
TZ=Australia/Sydney flutter test test/timezone_test.dart -v

# Check if tests passed
if [ $? -eq 0 ]; then
  echo "✅ Timezone tests passed successfully!"
else
  echo "❌ Timezone tests failed!"
  exit 1
fi

echo "Running general tests to ensure the fix doesn't break anything else..."
flutter test test/polar_test.dart

# Check if tests passed
if [ $? -eq 0 ]; then
  echo "✅ All tests passed successfully!"
else
  echo "❌ General tests failed - the timezone fix might have broken something else!"
  exit 1
fi

echo "Done! The timezone fix is working correctly." 