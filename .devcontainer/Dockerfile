ARG VARIANT="3.0"
FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends jq vim yamllint python3-pip python3-setuptools git less python3-dev

COPY requirements.txt /tmp/
RUN pip3 install --requirement /tmp/requirements.txt

RUN echo 'alias awsume="source awsume"' >> /home/${USER}/.bashrc \
    && mkdir /home/${USER}/.aws
