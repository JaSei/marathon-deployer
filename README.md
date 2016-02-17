# Marathon Deployer

[![Build Status](https://travis-ci.org/avast/marathon-deployer.svg?branch=master)](https://travis-ci.org/avast/marathon-deployer)

A simple script for deploying docker images to marathon-based cloud.

    docker run \
        -v /path/to/your/marathon.json:/marathon.json \
        -e MARATHON_URL=<your_marathon_url> avastsoftware/marathon-deployer

It will simply do the POST or PUT request to deploy your app and then verify the deployment is finished via another API call.

Optionally you can also provide these environment variables:
- MARATHON_JSON - name of your JSON file (default is marathon.json)
- MARATHON_APPLICATION_NAME - name of the application (id), this will be replaced in marathon json before submitting it
- MARATHON_INSTANCES - number of instances, this will be replaced in marathon json before submitting it
- MARATHON_DEPLOY_TIMEOUT_SECONDS - number of seconds for which the container waits for the deployment to be finished (default is 120)
- DOCKER_IMAGE_NAME - name of the docker image, this will be replaced in marathon json before submitting it

What it does for you:
- construct the URL to deploy
- do PUT request to marathon with provided JSON file
- parse response and set the return code accordingly
