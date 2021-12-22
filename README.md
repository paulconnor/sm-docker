# sm-docker

Sample Docker-Compose files to build siteminder docker containers for deployment to kubernetes via helm charts found here - https://github.com/paulconnor/siteminder

After cloning this repo
## 1. Build the Siteminder base image from Centos + Siteminder software installation packages 

> cd base

> docker-compose build

## 2. Build custom Siteminder images adding environment specific files/settings to the image created in Step 1.

> cd ../custom

> docker-compose build

## 3. Push the custom Siteminder images to your docker repo for Helm to use during depployment

> docker push \<docker-repo\>\/ag:custom

> docker push \<docker-repo\>\/ps:custom

> docker push \<docker-repo\>\/dx:custom
