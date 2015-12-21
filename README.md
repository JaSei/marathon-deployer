# Marathon Deployer

A simple script for deploying docker images to marathon-based cloud.

    docker run \
        -v /path/to/your/marathon.json:/marathon.json \
        -e MARATHON_URL=<your_marathon_url> avastsoftware/marathon-deployer

It will simply do the POST or PUT request to deploy your app.

Optionally you can also provide these environment variables:
- MARATHON_JSON - name of your JSON file (default is marathon.json)
- DOCKER_IMAGE_NAME - name of the docker image, this will be replaced in marathon json before submitting it

What it does for you:
- construct the URL to deploy
- do POST if app wasn't deployed yet
- do PUT if it was
- parse response and set the return code accordingly
