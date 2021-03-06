#!/bin/bash

# Copyright 2018 The Knative Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Test that pre/post integration tests don't run if unset.

source $(dirname $0)/presubmit-integration-tests-common.sh

function check_results() {
  (( ! PRE_INTEGRATION_TESTS )) || failed "Pre integration tests did run"
  (( CUSTOM_INTEGRATION_TESTS )) || failed "Custom integration tests did not run"
  (( ! POST_INTEGRATION_TESTS )) || failed "Post integration tests did run"
  echo "Test passed"
}

echo "Testing custom test integration function"

unset -f pre_integration_tests
unset -f post_integration_tests

main $@
