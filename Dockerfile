# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts-and-patches

COPY scripts/start-gitolite.sh /scripts/
COPY patches /patches

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG GITOLITE_VERSION
ARG PACKAGES_TO_INSTALL

# hadolint ignore=DL4006,SC2035,SC3044
RUN \
    --mount=type=bind,target=/scripts,from=with-scripts-and-patches,source=/scripts \
    --mount=type=bind,target=/patches,from=with-scripts-and-patches,source=/patches \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Install dependencies. \
    && homelab install util-linux patch \
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
    # Patch gitolite. \
    && pushd /opt/gitolite \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -r -n 1 patch -p2 -i) \
    && popd \
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
    && homelab remove util-linux patch \
    && homelab cleanup

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["--picoinit-cmd", "start-gitolite", "--picoinit-cmd", "tail", "-F", "/var/tmp/gitolite.log"]
STOPSIGNAL SIGTERM
