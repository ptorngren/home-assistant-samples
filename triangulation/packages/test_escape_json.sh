#!/bin/bash
# Test script for escape_json_string function

source ./bt_persistor_lib.sh

echo "Testing escape_json_string() function"
echo "======================================"
echo ""

# Test 1: Simple string
echo "Test 1: Simple string"
result=$(escape_json_string "Hello World")
echo "Input:  Hello World"
echo "Output: $result"
echo ""

# Test 2: String with double quotes
echo "Test 2: String with double quotes"
result=$(escape_json_string 'Device "75" Crystal UHD')
echo 'Input:  Device "75" Crystal UHD'
echo "Output: $result"
echo ""

# Test 3: String with backslash
echo "Test 3: String with backslash"
result=$(escape_json_string 'Path\To\Device')
echo 'Input:  Path\To\Device'
echo "Output: $result"
echo ""

# Test 4: String with brackets
echo "Test 4: String with brackets"
result=$(escape_json_string 'Foo[1]')
echo 'Input:  Foo[1]'
echo "Output: $result"
echo ""

# Test 5: String with non-ASCII characters
echo "Test 5: String with non-ASCII characters"
result=$(escape_json_string 'Värmland ÅkeskäR')
echo 'Input:  Värmland ÅkeskäR'
echo "Output: $result"
echo ""

# Test 6: Combined - quotes and backslashes
echo "Test 6: Combined - quotes and backslashes"
result=$(escape_json_string 'Path\"with\"backslash\and\"quotes')
echo 'Input:  Path\"with\"backslash\and\"quotes'
echo "Output: $result"
echo ""

# Test 7: Verify it produces valid JSON
echo "Test 7: Verify valid JSON array output"
name1=$(escape_json_string 'Device "A"')
name2=$(escape_json_string 'Device "B"')
json_output="{\"devices\":[$name1,$name2]}"
echo "JSON Output: $json_output"
echo ""
echo "Checking if valid JSON with jq (if available)..."
if command -v jq &> /dev/null; then
  if echo "$json_output" | jq . > /dev/null 2>&1; then
    echo "✓ Valid JSON!"
  else
    echo "✗ Invalid JSON!"
    echo "$json_output" | jq . 2>&1
  fi
else
  echo "(jq not available for validation)"
fi
