#!/bin/bash -l
#
# Copyright 2019-2020 Hewlett Packard Enterprise Development LP
#
###############################################################
#
#     CASM Test - Cray Inc.
#
#     TEST IDENTIFIER   : hmnfd_smoke_test
#
#     DESCRIPTION       : Automated test for verifying basic HMNFD API
#                         infrastructure and installation on Cray Shasta
#                         systems.
#                         
#     AUTHOR            : Mitch Schooler
#
#     DATE STARTED      : 04/29/2019
#
#     LAST MODIFIED     : 09/23/2020
#
#     SYNOPSIS
#       This is a smoke test for the HMS HMNFD API that makes basic HTTP
#       requests using curl to verify that the service's API endpoints
#       respond and function as expected after an installation.
#
#     INPUT SPECIFICATIONS
#       Usage: hmnfd_smoke_test
#       
#       Arguments: None
#
#     OUTPUT SPECIFICATIONS
#       Plaintext is printed to stdout and/or stderr. The script exits
#       with a status of '0' on success and '1' on failure.
#
#     DESIGN DESCRIPTION
#       This smoke test is based on the Shasta health check srv_check.sh
#       script in the CrayTest repository that verifies the basic health of
#       various microservices but instead focuses exclusively on the HMNFD 
#       API. It was implemented to run on the NCN of the system under test
#       within the DST group's Continuous Testing (CT) framework as part of
#       the ncn-smoke test suite.
#
#     SPECIAL REQUIREMENTS
#       Must be executed from the NCN.
#
#     UPDATE HISTORY
#       user       date         description
#       -------------------------------------------------------
#       schooler   04/29/2019   initial implementation
#       schooler   07/10/2019   add AuthN support for API calls
#       schooler   07/10/2019   update smoke test library location
#                               from hms-services to hms-common
#       schooler   08/19/2019   add initial check_pod_status test
#       schooler   09/06/2019   add test case documentation
#       schooler   09/09/2019   update smoke test library location
#                               from hms-common to hms-test
#       schooler   09/10/2019   update Cray copyright header
#       schooler   10/07/2019   switch from SMS to NCN naming convention
#       schooler   06/24/2020   add health, liveness, and readiness API tests
#       schooler   09/23/2020   use latest hms_smoke_test_lib
#
#     DEPENDENCIES
#       - hms_smoke_test_lib_ncn-resources_remote-resources.sh which is
#         expected to be packaged in
#         /opt/cray/tests/ncn-resources/hms/hms-test on the NCN.
#
#     BUGS/LIMITATIONS
#       None
#
###############################################################

# HMS test metrics test cases: 6
# 1. Check cray-hmnfd pod statuses
# 2. GET /health API response code
# 3. GET /liveness API response code
# 4. GET /readiness API response code
# 5. GET /subscriptions API response code
# 6. GET /params API response code

# initialize test variables
TEST_RUN_TIMESTAMP=$(date +"%Y%m%dT%H%M%S")
TEST_RUN_SEED=${RANDOM}
OUTPUT_FILES_PATH="/tmp/hmnfd_smoke_test_out-${TEST_RUN_TIMESTAMP}.${TEST_RUN_SEED}"
SMOKE_TEST_LIB="/opt/cray/tests/ncn-resources/hms/hms-test/hms_smoke_test_lib_ncn-resources_remote-resources.sh"
TARGET="api-gw-service-nmn.local"
CURL_ARGS="-i -s -S"
MAIN_ERRORS=0
CURL_COUNT=0

# cleanup
function cleanup()
{
    echo "cleaning up..."
    rm -f ${OUTPUT_FILES_PATH}*
}

# main
function main()
{
    # retrieve Keycloak authentication token for session
    TOKEN=$(get_auth_access_token)
    TOKEN_RET=$?
    if [[ ${TOKEN_RET} -ne 0 ]] ; then
        cleanup
        exit 1
    fi
    AUTH_ARG="-H \"Authorization: Bearer $TOKEN\""

    # GET tests
    for URL_ARGS in \
        "apis/hmnfd/hmi/v1/health" \
        "apis/hmnfd/hmi/v1/liveness" \
        "apis/hmnfd/hmi/v1/readiness" \
        "apis/hmnfd/hmi/v1/subscriptions" \
        "apis/hmnfd/hmi/v1/params"
    do
        URL=$(url "${URL_ARGS}")
        URL_RET=$?
        if [[ ${URL_RET} -ne 0 ]] ; then
            cleanup
            exit 1
        fi
        run_curl "GET ${AUTH_ARG} ${URL}"
        if [[ $? -ne 0 ]] ; then
            ((MAIN_ERRORS++))
        fi
    done

    echo "MAIN_ERRORS=${MAIN_ERRORS}"
    return ${MAIN_ERRORS}
}

# check_pod_status
function check_pod_status()
{
    run_check_pod_status "cray-hmnfd"
    return $?
}

trap ">&2 echo \"recieved kill signal, exiting with status of '1'...\" ; \
    cleanup ; \
    exit 1" SIGHUP SIGINT SIGTERM

# source HMS smoke test library file
if [[ -r ${SMOKE_TEST_LIB} ]] ; then
    . ${SMOKE_TEST_LIB}
else
    >&2 echo "ERROR: failed to source HMS smoke test library: ${SMOKE_TEST_LIB}"
    exit 1
fi

# make sure filesystem is writable for output files
touch ${OUTPUT_FILES_PATH}
if [[ $? -ne 0 ]] ; then
    >&2 echo "ERROR: output file location not writable: ${OUTPUT_FILES_PATH}"
    cleanup
    exit 1
fi

echo "Running hmnfd_smoke_test..."

# run initial pod status test
check_pod_status
if [[ $? -ne 0 ]] ; then
    echo "FAIL: hmnfd_smoke_test ran with failures"
    cleanup
    exit 1
fi

# run main API tests
main
if [[ $? -ne 0 ]] ; then
    echo "FAIL: hmnfd_smoke_test ran with failures"
    cleanup
    exit 1
else
    echo "PASS: hmnfd_smoke_test passed!"
    cleanup
    exit 0
fi
