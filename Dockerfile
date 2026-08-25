FROM python:2.7-buster

# Define metadata
LABEL maintainer="FBarrCa"

# Set arguments for flexibility
ARG PEBBLE_TOOL_VERSION=pebble-sdk-4.5-linux64
ARG PEBBLE_SDK_VERSION=4.3
ARG NODE_VERSION=10.16.2
ARG NVM_VERSION=0.35.0

# Set environment variables
ENV PEBBLE_TOOL_VERSION=${PEBBLE_TOOL_VERSION}
ENV PEBBLE_SDK_VERSION=${PEBBLE_SDK_VERSION}
ENV NVM_DIR=/home/pebble/.nvm
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:/opt/${PEBBLE_TOOL_VERSION}/bin:$PATH"

# Update system and install required dependencies
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends \
        curl \
        libfreetype6-dev \
        bash-completion \
        libsdl1.2debian \
        libfdt1 \
        libpixman-1-0 \
        libglib2.0-dev \
        vim \
        zsh \
        git \
        wget \
        firefox-esr \
        python-virtualenv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download and extract Pebble SDK
RUN curl -sSL https://developer.rebble.io/s3.amazonaws.com/assets.getpebble.com/pebble-tool/${PEBBLE_TOOL_VERSION}.tar.bz2 \
    | tar -xj -C /opt/

# Set working directory to Pebble SDK
WORKDIR /opt/${PEBBLE_TOOL_VERSION}

# Create and activate a virtual environment
RUN virtualenv .env && \
    /bin/bash -c "source .env/bin/activate && \
    sed -i '/pypkjs/d' requirements.txt && \
    pip install -r requirements.txt https://github.com/Willow-Systems/vagrant-pebble-sdk/raw/master/pypkjs-1.0.6.tar.gz && \
    deactivate"

# Remove unnecessary cache
RUN rm -rf /root/.cache/

# Create a non-root user and disable analytics
RUN adduser --disabled-password --gecos "" --ingroup users pebble && \
    echo "pebble ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/pebble/.pebble-sdk/ && \
    chown -R pebble:users /home/pebble/.pebble-sdk && \
    touch /home/pebble/.pebble-sdk/NO_TRACKING

# Install Oh My Zsh manually (as the pebble user)
USER pebble
RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh && \
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc && \
    echo "export PATH=${PATH}" >> ~/.zshrc && \
    echo "export NVM_DIR=${NVM_DIR}" >> ~/.zshrc && \
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> ~/.zshrc && \
    echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"" >> ~/.zshrc && \
    echo "source /opt/${PEBBLE_TOOL_VERSION}/.env/bin/activate" >> ~/.zshrc

# Set default shell to Zsh
USER root
RUN usermod --shell $(which zsh) pebble

# Switch to non-root user for further installations
USER pebble

# Install NVM and Node.js
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION

# Download and install Pebble SDK
RUN curl -L -o /tmp/sdk-core-${PEBBLE_SDK_VERSION}.tar.bz2 \
    https://github.com/aveao/PebbleArchive/raw/master/SDKCores/sdk-core-${PEBBLE_SDK_VERSION}.tar.bz2 && \
    pebble sdk install /tmp/sdk-core-${PEBBLE_SDK_VERSION}.tar.bz2 && \
    pebble sdk activate ${PEBBLE_SDK_VERSION} && \
    rm /tmp/sdk-core-${PEBBLE_SDK_VERSION}.tar.bz2

# Define mountable volume for projects
VOLUME /workspace/

# Set default working directory
WORKDIR /workspace/

# Default command
CMD ["zsh"]
