FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    STEAM_LINUX_USER=steam \
    STEAM_HOME=/home/steam \
    LINUXGSM_VERSION=v25.2.0

SHELL ["/bin/bash", "-lc"]

RUN dpkg --add-architecture armhf \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    tar \
    xz-utils \
    file \
    tmux \
    bc \
    jq \
    sudo \
    procps \
    iproute2 \
    unzip \
 && libcurl_armhf="$(if apt-cache show libcurl4t64:armhf >/dev/null 2>&1; then echo libcurl4t64:armhf; else echo libcurl4:armhf; fi)" \
 && libssl_armhf="$(if apt-cache show libssl3t64:armhf >/dev/null 2>&1; then echo libssl3t64:armhf; else echo libssl3:armhf; fi)" \
 && apt-get install -y --no-install-recommends \
    libc6:armhf \
    libstdc++6:armhf \
    libgcc-s1:armhf \
    zlib1g:armhf \
    libbz2-1.0:armhf \
    libncurses6:armhf \
    libtinfo6:armhf \
    "${libssl_armhf}" \
    "${libcurl_armhf}" \
    libudev1:armhf \
    libdbus-1-3:armhf \
    libsdl2-2.0-0:armhf \
 && curl -fsSL https://ryanfortner.github.io/box86-debs/box86.list -o /etc/apt/sources.list.d/box86.list \
 && curl -fsSL https://ryanfortner.github.io/box64-debs/box64.list -o /etc/apt/sources.list.d/box64.list \
 && curl -fsSL https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/box86-debs-archive-keyring.gpg \
 && curl -fsSL https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg \
 && apt-get update \
 && apt-get install -y --no-install-recommends box64 box86-generic-arm \
 && useradd -m -s /bin/bash "${STEAM_LINUX_USER}" \
 && printf '%s\n' "${STEAM_LINUX_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/steam \
 && chmod 0440 /etc/sudoers.d/steam \
 && install -d -o "${STEAM_LINUX_USER}" -g "${STEAM_LINUX_USER}" \
    "${STEAM_HOME}/steamcmd" \
    "${STEAM_HOME}/serverfiles" \
    "${STEAM_HOME}/Steam" \
    "${STEAM_HOME}/bin" \
    "${STEAM_HOME}/.steam/sdk32" \
    "${STEAM_HOME}/.steam/sdk64" \
    "${STEAM_HOME}/lgsm/data" \
    "${STEAM_HOME}/lgsm/modules" \
    "${STEAM_HOME}/lgsm/config-lgsm/l4d2server" \
    "${STEAM_HOME}/serverfiles/left4dead2/cfg" \
    "${STEAM_HOME}/log" \
 && sudo -u "${STEAM_LINUX_USER}" -H bash -lc 'cd ~/steamcmd && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xzf -' \
 && sudo -u "${STEAM_LINUX_USER}" -H bash -lc 'ln -sf ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so; if [ -f ~/steamcmd/linux64/steamclient.so ]; then ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so; fi' \
 && rm -rf /var/lib/apt/lists/*

COPY . /opt/l4d2-arm

RUN install -m 755 /opt/l4d2-arm/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh \
 && install -m 755 /opt/l4d2-arm/steamcmd-box86 "${STEAM_HOME}/bin/steamcmd-box86" \
 && install -m 755 /opt/l4d2-arm/steamcmd "${STEAM_HOME}/bin/steamcmd" \
 && install -m 755 /opt/l4d2-arm/steamcmd-login-test.sh "${STEAM_HOME}/bin/steamcmd-login-test.sh" \
 && install -m 755 /opt/l4d2-arm/l4d2-steamcmd-install.sh "${STEAM_HOME}/bin/l4d2-steamcmd-install.sh" \
 && install -m 755 /opt/l4d2-arm/srcds-arm.sh "${STEAM_HOME}/bin/srcds-arm.sh" \
 && install -m 644 /opt/l4d2-arm/linuxgsm/common.cfg "${STEAM_HOME}/lgsm/config-lgsm/l4d2server/common.cfg" \
 && install -m 644 /opt/l4d2-arm/linuxgsm/l4d2server.cfg "${STEAM_HOME}/lgsm/config-lgsm/l4d2server/l4d2server.cfg" \
 && install -m 644 /opt/l4d2-arm/linuxgsm-modules/check_system_requirements.sh "${STEAM_HOME}/lgsm/modules/check_system_requirements.sh" \
 && install -m 644 /opt/l4d2-arm/linuxgsm-modules/check_deps.sh "${STEAM_HOME}/lgsm/modules/check_deps.sh" \
 && install -m 644 /opt/l4d2-arm/game/l4d2server.cfg "${STEAM_HOME}/serverfiles/left4dead2/cfg/l4d2server.cfg" \
 && chown -R "${STEAM_LINUX_USER}:${STEAM_LINUX_USER}" "${STEAM_HOME}"

WORKDIR /home/steam

EXPOSE 27015/tcp 27015/udp 27005/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["server"]
