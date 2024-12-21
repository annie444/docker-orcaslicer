FROM kasmweb/core-ubuntu-noble:1.16.1-rolling-weekly
USER root

ARG BUILD_DATE
ARG VERSION
ARG ORCASLICER_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

# title
ENV TITLEOrcaSlicer \
    SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt

RUN curl -o \
      /usr/share/backgrounds/bg_default.png \
      https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/orcaslicer-logo.png && \
    DEBIAN_FRONTEND=noninteractive \
    add-apt-repository ppa:kisak/kisak-mesa && \
    apt-get update -y && \
    apt-get install --no-install-recommends -y \
      firefox \
      gstreamer1.0-alsa \
      gstreamer1.0-gl \
      gstreamer1.0-gtk3 \
      gstreamer1.0-libav \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-base \
      gstreamer1.0-plugins-good \
      gstreamer1.0-plugins-ugly \
      gstreamer1.0-pulseaudio \
      gstreamer1.0-qt5 \
      gstreamer1.0-tools \
      gstreamer1.0-x \
      libgstreamer1.0-0 \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-base \
      libwebkit2gtk-4.1-0 \
      libwx-perl && \
    apt-get upgrade -y && \
    if [ -z ${ORCASLICER_VERSION+x} ]; then \
      ORCASLICER_VERSION=$(curl -sX GET "https://api.github.com/repos/SoftFever/OrcaSlicer/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]'); \
    fi && \
    ORCASLICER_UPPER_VERSION=$(echo ${ORCASLICER_VERSION} | sed 's/\b\(.\)/\u\1/g') && \
    mkdir /opt && \
    cd /tmp && \
    curl -o \
      /tmp/orca.app -L \
      "https://github.com/SoftFever/OrcaSlicer/releases/download/${ORCASLICER_VERSION}/OrcaSlicer_Linux_Ubuntu2404_${ORCASLICER_UPPER_VERSION}.AppImage" && \
    chmod +x /tmp/orca.app && \
    ./orca.app --appimage-extract && \
    mv /tmp/squashfs-root /opt/orcaslicer && \
    apt-get autoclean && \
    rm -rf \
      /config/.cache \
      /config/.launchpadlib \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /tmp/*

COPY root/custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh
RUN chmod 755 $STARTUPDIR/custom_startup.sh

RUN cp $HOME/.config/xfce4/xfconf/single-application-xfce-perchannel-xml/* $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/
RUN apt-get remove -y xfce4-panel

# add local files
COPY OrcaSlicer/ $HOME/.config/OrcaSlicer/

RUN chown -R 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME
RUN find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \; && \
    if [ -z ${SKIP_CLEAN+x} ]; then \
      apt-get autoclean; \
      rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*; \
    fi

ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
