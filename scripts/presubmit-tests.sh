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

# This is a helper script for Knative presubmit test scripts.
# See README.md for instructions on how to use it.

source $(dirname ${BASH_SOURCE})/library.sh

# Extensions or file patterns that don't require presubmit tests.
readonly NO_PRESUBMIT_FILES=(\.md \.png ^OWNERS)

# Options set by command-line flags.
RUN_BUILD_TESTS=0
RUN_UNIT_TESTS=0
RUN_INTEGRATION_TESTS=0
EMIT_METRICS=0

# Exit presubmit tests if only documentation files were changed.
function exit_if_presubmit_not_required() {
  if [[ -n "${PULL_PULL_SHA}" ]]; then
    # On a presubmit job
    local changes="$(/workspace/githubhelper -list-changed-files)"
    if [[ -z "${changes}" ]]; then
      header "NO CHANGED FILES REPORTED, ASSUMING IT'S AN ERROR AND RUNNING TESTS ANYWAY"
      return
    fi
    local no_presubmit_pattern="${NO_PRESUBMIT_FILES[*]}"
    local no_presubmit_pattern="\(${no_presubmit_pattern// /\\|}\)$"
    echo -e "Changed files in commit ${PULL_PULL_SHA}:\n${changes}"
    if [[ -z "$(echo "${changes}" | grep -v ${no_presubmit_pattern})" ]]; then
      # Nothing changed other than files that don't require presubmit tests
      header "Commit only contains changes that don't affect tests, skipping"
      exit 0
    fi
  fi
}

# Process flags and run tests accordingly.
function main() {
  exit_if_presubmit_not_required

  # Show the version of the tools we're using
  if (( IS_PROW )); then
    # Disable gcloud update notifications
    gcloud config set component_manager/disable_update_check true
    header "Current test setup"
    echo ">> gcloud SDK version"
    gcloud version
    echo ">> kubectl version"
    kubectl version
    echo ">> go version"
    go version
  fi

  local all_parameters=$@
  [[ -z $1 ]] && all_parameters="--all-tests"

  for parameter in ${all_parameters}; do
    case ${parameter} in
      --all-tests)
        RUN_BUILD_TESTS=1
        RUN_UNIT_TESTS=1
        RUN_INTEGRATION_TESTS=1
        shift
        ;;
      --build-tests)
        RUN_BUILD_TESTS=1
        shift
        ;;
      --unit-tests)
        RUN_UNIT_TESTS=1
        shift
        ;;
      --integration-tests)
        RUN_INTEGRATION_TESTS=1
        shift
        ;;
      --emit-metrics)
        EMIT_METRICS=1
        shift
        ;;
      *)
        echo "error: unknown option ${parameter}"
        exit 1
        ;;
    esac
  done

  readonly RUN_BUILD_TESTS
  readonly RUN_UNIT_TESTS
  readonly RUN_INTEGRATION_TESTS
  readonly EMIT_METRICS

  cd ${REPO_ROOT_DIR}

  # Tests to be performed, in the right order if --all-tests is passed.

  local failed=0
  if (( RUN_BUILD_TESTS )); then
    build_tests || failed=1
  fi
  if (( RUN_UNIT_TESTS )); then
    unit_tests || failed=1
  fi
  if (( RUN_INTEGRATION_TESTS )); then
    if function_exists pre_integration_tests; then
      pre_integration_tests || failed=1
    fi
    if (( ! failed )); then
      if function_exists integration_tests; then
        integration_tests || failed=1
      else
       local options=""
       (( EMIT_METRICS )) && options="--emit-metrics"
       ./test/e2e-tests.sh ${options} || failed=1
      fi
    fi
    if (( ! failed )) && function_exists post_integration_tests; then
      post_integration_tests || failed=1
    fi
  fi
  exit ${failed}
}
