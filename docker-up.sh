#!/bin/bash
FILE=$1

if [[ $# -le 0 ]]; then
    echo "You must include an argument, e.g., 'docker-compose-w-db.yml', 'docker-compose.yml', etc."
    exit 2
fi

# Pulls image if it doesn't exist on local, also updates the image if it already exists on local
docker pull omcds-docker.dockerhub-phx.oci.oraclecorp.com/python-base-libs-nextgen:latest
cd src/
rm -rf dist/ build/ minerva.egg-info/
python3 setup.py sdist bdist_wheel
cd ..
docker system prune -f --volumes
compose="docker-compose"
while [ ! -z "$1" ]; do
	compose="$compose -f $1"
	shift
done
compose="$compose up --build"
$compose
#-d --build
