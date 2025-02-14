#!/usr/bin/env bash

set -x
set -e
set -o pipefail

# This script checks whether the current PR meets the additional reviewer
# requirement for release PRs. Non-release PRs succeed by default.
# It uses the GitHub Status API to accomplish this. See the actual API call
# at the end of the file for more details.

GITHUB_REPOSITORY=${1}

if [[ -z $GITHUB_REPOSITORY ]]; then
  echo "Error: No GitHub repository identifier specified."
  exit 1
fi

GITHUB_STATUS_NAME=${2}

if [[ -z $GITHUB_STATUS_NAME ]]; then
  echo 'Error: No GitHub status name specified.'
  exit 1
fi

IS_RELEASE=${3}

if [[ -z $IS_RELEASE ]]; then
  echo 'Error: No "is release" input specified.'
  exit 1
fi

NUM_OTHER_APPROVING_REVIEWERS=${4}

if [[ $IS_RELEASE == "true" && -z $NUM_OTHER_APPROVING_REVIEWERS ]]; then
  echo "Error: No count of other approving reviewers specified."
  exit 1
fi

HEAD_COMMIT_SHA=$(git rev-parse HEAD)

if [[ -z $HEAD_COMMIT_SHA ]]; then
  echo 'Error: "git rev-parse HEAD" returned an empty value.'
  exit 1
fi

# Compute the status for the current commit and set it via the GitHub API.

COMMIT_STATUS_DESCRIPTION="Whether this PR meets the additional reviewer requirement for releases."

if [[ "$IS_RELEASE" == "false" ]]; then
  echo "The PR is not a release PR. Setting status to success by default."
  # Non-Release PRs might be opened by a community contributor using a fork,
  # which cannot set a commit status due to lack of write permissions
  # (see https://github.community/t/github-actions-are-severely-limited-on-prs/18179)
  # Exiting will set the status to "success" anyway.
  exit 0
elif (( NUM_OTHER_APPROVING_REVIEWERS > 0 )); then
  echo "Success! Found approving reviews from organization members."
  COMMIT_STATUS="success"
else
  echo "Failure: Did not find approving reviews from other organization members."
  COMMIT_STATUS="pending"
fi

# https://cli.github.com/manual/gh_api
# https://docs.github.com/en/rest/reference/repos#create-a-commit-status
# Warning! Setting commit status fails if the pull request was opened from a fork
# See https://github.community/t/github-actions-are-severely-limited-on-prs/18179

gh api "https://api.github.com/repos/${GITHUB_REPOSITORY}/statuses/${HEAD_COMMIT_SHA}" \
  -X "POST" \
  -H "Accept: application/vnd.github.v3+json" \
  -f context="$GITHUB_STATUS_NAME" \
  -f description="$COMMIT_STATUS_DESCRIPTION" \
  -f state="$COMMIT_STATUS"

# The action should never fail, only set a status for the release branch HEAD
# commit.
