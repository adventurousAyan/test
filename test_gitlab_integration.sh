#!/usr/bin/env bash

# tests/integration/test_gitlab_integration.sh
# Print commands
FILE=$1
set -x
# Delete datascience directory if exists
[[ -d /datascience ]] && rm -rf /datascience

docker_compose_cmd="docker-compose -f docker-compose.yml -f docker-compose-oracle-db.yml"
# Run service containers, except for test container
echo "Bringing up the containers"
${docker_compose_cmd} up -d --build

# Sleep 7m in order for DB Warm Up
echo "Sleep 7m in order for DB Warm Up"
sleep 7m

#Initialize the DB Scripts
echo "Preparing the DB Container"
docker exec -i minerva-core-nextgen_oracle_db_1 /bin/bash -c "
echo Inside DB Container;
echo Setting Path variable;
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/u01/app/oracle/product/12.2.0/dbhome_1/bin ; 
echo Setting TNS_ADMIN;
export TNS_ADMIN=/u01/app/oracle/product/12.2.0/dbhome_1/admin/ORCL; 
echo Running DB Initialization Scripts;
sh /scripts/db/init-db.sh"

echo "DB Container initialization completed"

# Run the tests
echo "Preparing the Minerva container"
docker exec -i minerva-core-nextgen_ds_core_1 /bin/bash -c "
export https_proxy=http://www-proxy.us.oracle.com:80;
export http_proxy=http://www-proxy.us.oracle.com:80;
export no_proxy=localhost,127.0.0.1,.us.oracle.com;
python3 /usr/local/bin/deployment_utils/base_install_apps.py --build_mode ${MINERVA_BUILD_MODE} ;
cd /src;
pip install pytest;
echo Running Integration Tests;
pytest tests/integration/"

# keep the exit code from tests while we clean up the containers
exit_code=$?

# Clean up
echo "Bringing down the containers"
${docker_compose_cmd} down

# return the original result of the test - for GitLab CI
exit ${exit_code}