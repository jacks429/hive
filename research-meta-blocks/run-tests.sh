#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

set -e

echo "Running meta-block tests..."

# Run the tests using nix eval
result=$(nix eval --impure --expr "
  let
    pkgs = import <nixpkgs> {};
    tests = import ./test-codegen.nix { inherit (pkgs) lib; pkgs = pkgs; };
  in
    tests.allTests
")

if [ "$result" = "true" ]; then
  echo "All tests passed!"
  exit 0
else
  echo "Tests failed!"
  exit 1
fi
