#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment to enable stub debugging
# export CURL_STUB_DEBUG=3
# export BUILDKITE_AGENT_STUB_DEBUG=3

# Source the command and print environment variables to allow for assertions.
# This could be done by skipping the "run" command, but it makes for a more readable test.
run_test_command() {
  source "$@"

  echo "TESTRESULT:PULUMI_ACCESS_TOKEN=${PULUMI_ACCESS_TOKEN:-"<value not set>"}"
}

@test "fails when org_name is missing" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  unset BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME

  run source "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Missing 'org_name' plugin configuration"
}

@test "fails on invalid JSON response" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "not valid json"'

  run source "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "invalid JSON response body"

  unstub curl
  unstub buildkite-agent
}

@test "fails on HTTP 500 error" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "curl: (22) The requested URL returned error: 500" >&2; exit 22'

  run source "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Requesting API token failed, curl exited with status 22"

  unstub curl
  unstub buildkite-agent
}

@test "calls token exchange with correct org" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "{\"access_token\": \"pul-TOKEN\"}"'

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "TESTRESULT:PULUMI_ACCESS_TOKEN=pul-TOKEN"

  unstub curl
  unstub buildkite-agent
}


@test "calls token exchange lifetime" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_LIFETIME=3600

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 3600 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "{\"access_token\": \"pul-TOKEN\"}"'

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "TESTRESULT:PULUMI_ACCESS_TOKEN=pul-TOKEN"

  unstub curl
  unstub buildkite-agent
}


@test "calls token exchange with scope and token_type" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_REQUESTED_TOKEN_TYPE="urn:pulumi:token-type:access_token:team"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_SCOPE="team:acme_team"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:team -d scope=team:acme_team -d subject_token=buildkite-oidc-token -f : echo "{\"access_token\": \"pul-TOKEN\"}"'

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "TESTRESULT:PULUMI_ACCESS_TOKEN=pul-TOKEN"

  unstub curl
  unstub buildkite-agent
}

@test "uses custom backend URL" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_BACKEND_URL="https://pulumi.example.com"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://pulumi.example.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "{\"access_token\": \"pul-TOKEN\"}"'

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "TESTRESULT:PULUMI_ACCESS_TOKEN=pul-TOKEN"

  unstub curl
  unstub buildkite-agent
}

@test "fails on API error response" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:organization -d subject_token=buildkite-oidc-token -f : echo "{\"error\": \"invalid_grant\", \"error_description\": \"authorization policy denied the token exchange\"}"'

  run source "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Requesting API token failed"
  assert_output --partial "invalid_grant: authorization policy denied the token exchange"

  unstub curl
  unstub buildkite-agent
}

@test "Debug option" {
  export BUILDKITE_JOB_ID="job-uuid-42"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_ORG_NAME="acme_org"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_REQUESTED_TOKEN_TYPE="urn:pulumi:token-type:access_token:team"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_SCOPE="team:acme_team"
  export BUILDKITE_PLUGIN_PULUMI_OIDC_DEBUG="true"

  stub buildkite-agent 'oidc request-token --audience urn:pulumi:org:acme_org --lifetime 0 : echo "buildkite-oidc-token"'
  stub curl '-sS -X POST https://api.pulumi.com/api/oauth/token -H Content-Type:\ application/x-www-form-urlencoded -d subject_token_type=urn:ietf:params:oauth:token-type:id_token -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d audience=urn:pulumi:org:acme_org -d requested_token_type=urn:pulumi:token-type:access_token:team -d scope=team:acme_team -d subject_token=buildkite-oidc-token -f : echo "{\"access_token\": \"pul-TOKEN\"}"'

  run run_test_command $PWD/hooks/environment

  assert_success
  assert_output --partial "~~~ Pulumi API token exchange cmd:"
  assert_output --partial "~~~ Pulumi API token exchange response:"
  assert_output --partial "{\"access_token\": \"pul-TOKEN\"}"
  assert_output --partial "TESTRESULT:PULUMI_ACCESS_TOKEN=pul-TOKEN"

  unstub curl
  unstub buildkite-agent
}
