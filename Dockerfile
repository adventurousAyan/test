# `Appropiate version of `python-base-libs-nextgen` will now get pulled for every release.
#  For local and develop branch build, latest version would be pulled
ARG MINERVA_RELEASE_VERSION
FROM omcds-docker.dockerhub-phx.oci.oraclecorp.com/python-base-libs-nextgen:$MINERVA_RELEASE_VERSION

COPY src/dist /dist

ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG MINERVA_STORAGE_HOME
ARG MINERVA_LOGS_HOME
ARG MINERVA_CERT_HOME
ARG MINERVA_USER_ID
ARG MINERVA_USER_NAME
ARG MINERVA_USER_GROUP
ARG REST_PORT
ARG HUB_STORAGE_ENABLED
# To check whether we build in release vs dev mode
ARG MINERVA_BUILD_MODE
# Version of minerva-configs
ARG MINERVA_CONFIG_VERSION

RUN if [[ ! -z "$http_proxy" ]] || [[ ! -z "$https_proxy" ]]; then export http_proxy=$http_proxy\nexport https_proxy=$https_proxy; fi

# Create Minerva user and group
RUN groupadd -g ${MINERVA_USER_ID} ${MINERVA_USER_GROUP} \
  && useradd -u ${MINERVA_USER_ID} -g ${MINERVA_USER_NAME} -ms /bin/bash ${MINERVA_USER_NAME} 

RUN mkdir -p ${MINERVA_STORAGE_HOME}

RUN python3 -m pip install --user --upgrade setuptools wheel \
  && python3 -m pip install /dist/*.whl \
  && rm -r /dist/

COPY ./deployment/odbcinst.ini /etc/odbcinst.ini

# Include deployment utilities script
COPY ./deployment/deployment_utils/* /usr/local/bin/deployment_utils/

# Install Minerva-Configs wheel
RUN chmod +x /usr/local/bin/deployment_utils/exec-install-utils.py \
&& python3 /usr/local/bin/deployment_utils/exec-install-utils.py --build_mode $MINERVA_BUILD_MODE --pip_config_version $MINERVA_CONFIG_VERSION

# setup rsyslog conf  
COPY ./deployment/rsyslog.conf /etc/rsyslog.conf

COPY ./deployment/logrotate-minerva.conf /etc/logrotate.d/logrotate-minerva.conf

COPY ./deployment/cron-logrotate /etc/cron.d/cron-logrotate

COPY ./deployment/*nginx.conf /etc/nginx/
COPY ./deployment/setup-nginx.sh /usr/local/bin/setup-nginx.sh

# Copy the base uWSGI ini file to enable default dynamic uwsgi process number
COPY ./deployment/uwsgi.ini /etc/uwsgi/apps-available/uwsgi.ini

# Copy and set up supervisor
COPY ./deployment/supervisord.conf /usr/local/etc/supervisord.conf

# setup entrypoint
COPY ./deployment/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# docker-entrypoint will run shell scripts based on product name at container startup
COPY ./deployment/minerva_db/common_db_ddl /usr/local/bin/common_db_ddl


COPY ./deployment/minerva-dir-mgmt.sh /usr/local/bin/minerva-dir-mgmt.sh
COPY ./deployment/minerva-setup.sh /usr/local/bin/minerva-setup.sh

# Set permissions
RUN chown ${MINERVA_USER_NAME}:${MINERVA_USER_GROUP} /usr/local/bin/minerva-dir-mgmt.sh /usr/local/bin/docker-entrypoint.sh /usr/local/bin/minerva-setup.sh \
&& chmod 755 /usr/local/bin/minerva-dir-mgmt.sh /usr/local/bin/docker-entrypoint.sh /usr/local/bin/minerva-setup.sh


WORKDIR /$MINERVA_STORAGE_HOME


COPY ./deployment/dataplane_schemas/*.json /temp_schemas/


# Gets copied in image, but gets overwritten when container's MINERVA_CERT_HOME volume gets mount to host
COPY ./src/minerva/pem/keystore ./src/minerva/pem/keystore.txt  $MINERVA_CERT_HOME/

RUN chown -R $MINERVA_USER_NAME:$MINERVA_USER_GROUP $MINERVA_CERT_HOME


RUN ln -s /usr/local/bin/docker-entrypoint.sh \
  && chmod 777 /usr/local/bin/docker-entrypoint.sh \
  && chgrp -R 0 /usr/local/bin/docker-entrypoint.sh \
  && unset http_proxy https_proxy

# Download nltk data
RUN [ "python3", "-c", "import nltk; nltk.download('punkt', download_dir='/usr/nltk_data/');nltk.download('stopwords',download_dir='/usr/nltk_data/');" ]
RUN chmod --recursive -f 777 /usr/nltk_data

ARG REST_PORT
EXPOSE ${REST_PORT}

ENTRYPOINT ["docker-entrypoint.sh"]


# DEBUG with this: instead of supervisord
# CMD ["tail","-f","/dev/null"]
