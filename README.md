[![Build Status](https://travis-ci.org/avast/marathon-deployer.svg?branch=master)](https://travis-ci.org/avast/marathon-deployer)
# NAME

App::MarathonDeployer - deployment to mesos-marathon

# SYNOPSIS

# DESCRIPTION

A simple script for deploying docker images to marathon-based cloud.

    docker run \
        -v /path/to/your/marathon.json:/marathon.json \
        -e MARATHON_URL=<your_marathon_url> avastsoftware/marathon-deployer

It will simply do the POST or PUT request to deploy your app.

Optionally you can also provide these environment variables:
\- MARATHON\_JSON - name of your JSON file (default is marathon.json)
\- MARATHON\_APPLICATION\_NAME - name of the application (id), this will be replaced in marathon json before submitting it
\- MARATHON\_INSTANCES - number of instances, this will be replaced in marathon json before submitting it
\- DOCKER\_IMAGE\_NAME - name of the docker image, this will be replaced in marathon json before submitting it
\- CPU\_PROFILE - one of low|normal|high. If cpus is not set in marathon.json, it gets computed from total cloud's CPU/memory ratio. If you choose normal profile, the cpus is set to mem \* ratio, low = 0.3 \* normal, high = 3 \* normal.

What it does for you:
\- construct the URL to deploy
\- do PUT request to marathon with provided JSON file
\- parse response and set the return code accordingly

# LICENSE

Copyright (C) Avast Software

# AUTHOR

Miroslav Tynovsky <tynovsky@avast.com>
