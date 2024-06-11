# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

COPY scripts/start-gitolite.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG GITOLITE_VERSION
ARG PACKAGES_TO_INSTALL

RUN --mount=type=bind,target=/scripts,from=with-scripts,source=/scripts \
    set -e -o pipefail \
    # Install dependencies. \
    && homelab install util-linux \
    && homelab install $PACKAGES_TO_INSTALL \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    # Download and install the release. \
    && homelab install-git-repo \
        https://github.com/sitaramc/gitolite \
        ${GITOLITE_VERSION:?} \
        gitolite \
        gitolite-${GITOLITE_VERSION:?} \
        ${USER_NAME:?} \
        ${GROUP_NAME:?} \
    # Set up the necessary directories along with granting \
    # permissions to the user we created. \
    && mkdir -p /run /var/run/sshd /opt/logs \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /run/ /var/run/sshd /etc/ssh /opt/logs /opt/gitolite /opt/gitolite-${GITOLITE_VERSION:?} \
    && chmod o+w /opt/bin \
    # Install the gitolite binary. \
    && su --login --shell /bin/bash --command "/opt/gitolite/install -ln /opt/bin" ${USER_NAME:?} \
    && chmod o-w /opt/bin \
    # Copy the start-gitolite.sh script. \
    && cp /scripts/start-gitolite.sh /opt/gitolite/ \
    && ln -sf /opt/gitolite/start-gitolite.sh /opt/bin/start-gitolite \
    # Clean up. \
    && homelab remove util-linux \
    && homelab cleanup

ENV USER=${USER_NAME}
ENV PATH="/opt/bin:${PATH}"

USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}
CMD ["start-gitolite"]
STOPSIGNAL SIGQUIT
