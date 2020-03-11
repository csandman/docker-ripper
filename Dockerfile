# Use phusion/passenger-full as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/passenger-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/passenger-full:1.0.9
MAINTAINER csandman
# Or, instead of the 'full' variant, use one of these:
#FROM phusion/passenger-ruby23:<VERSION>
#FROM phusion/passenger-ruby24:<VERSION>
#FROM phusion/passenger-ruby25:<VERSION>
#FROM phusion/passenger-ruby26:<VERSION>
#FROM phusion/passenger-jruby92:<VERSION>
#FROM phusion/passenger-nodejs:<VERSION>
#FROM phusion/passenger-customizable:<VERSION>

# Set correct environment variables.
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
# ENV MAKEMKV_PROFILE default
ENV NASM_VERSION 2.13.01
ENV FDKAAC_VERSION 0.1.6
ENV LIBX265_VERSION 2.9
ENV HANDBRAKE_VERSION 1.1.2
ENV FFMPEG_VERSION 4.1

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# If you're using the 'customizable' variant, you need to explicitly opt-in
# for features.
#
# N.B. these images are based on https://github.com/phusion/baseimage-docker,
# so anything it provides is also automatically on board in the images below
# (e.g. older versions of Ruby, Node, Python).
#
# Uncomment the features you want:
#
#   Ruby support
#RUN /pd_build/ruby-2.3.*.sh
#RUN /pd_build/ruby-2.4.*.sh
#RUN /pd_build/ruby-2.5.*.sh
#RUN /pd_build/ruby-2.6.5.sh
#RUN /pd_build/jruby-9.2.*.sh
#   Python support.
#RUN /pd_build/python.sh
#   Node.js and Meteor standalone support.
#   (not needed if you already have the above Ruby support)
#RUN /pd_build/nodejs.sh

# ...put your own build instructions here...

# Configure user nobody to match unRAID's settings
RUN \
  usermod -u 99 nobody && \
  usermod -g 100 nobody && \
  usermod -d /home nobody && \
  chown -R nobody:users /home

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Move Files
COPY root/ /
RUN chmod +x /etc/my_init.d/*.sh

# EXTRA PERMISSIONS?
RUN chown root:root /tmp
RUN chmod ugo+rwXt /tmp

# RESET TIME?
# RUN hwclock --hctosys 

# Install software
RUN apt-get update \
  && apt-get -y --allow-unauthenticated install wget eject lame curl tree


# MakeMKV setup by github.com/tobbenb
RUN chmod +x /tmp/install/install.sh
RUN sleep 1
RUN /tmp/install/install.sh

# install build dependencies to compile ffmpeg from master
RUN set -ex \
  && buildDeps=' \
  autoconf \
  automake \
  build-essential \
  git \
  libass-dev \
  libbz2-dev \
  libfontconfig1-dev \
  libfreetype6-dev \
  libfribidi-dev \
  libharfbuzz-dev \
  libjansson-dev \
  libogg-dev \
  libsamplerate-dev \
  libtheora-dev \
  libtool \
  libvorbis-dev \
  libxml2-dev \
  m4 \
  make \
  patch \
  pkg-config \
  python \
  tar \
  libtool-bin \
  texinfo \
  wget \
  zlib1g-dev \
  yasm \
  cmake \
  cmake-curses-gui \
  mercurial \
  libmp3lame-dev \
  libopus-dev \
  libvpx-dev \
  libx264-dev \
  unzip \
  mkvtoolnix \
  mp4v2-utils \
  mpv \
  ' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \
  && mkdir -p /usr/src/ffmpeg/bin \
  && mkdir -p /usr/src/ffmpeg/build \
  && PATH="/usr/src/ffmpeg/bin:$PATH" \
  && cd /usr/src/ffmpeg \
  # NASM
  && wget http://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.bz2 \
  && tar xjvf nasm-*.tar.bz2 \
  && cd nasm-* \
  && ./autogen.sh \
  && PATH="/usr/src/ffmpeg/bin:$PATH" ./configure --prefix="/usr/src/ffmpeg/build" --bindir="/usr/src/ffmpeg/bin" \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf nasm-* \
  # libx264 stable
  && git clone -b stable http://git.videolan.org/git/x264.git x264 \
  && cd x264 \
  && PATH="/usr/src/ffmpeg/bin:$PATH" ./configure --prefix="/usr/src/ffmpeg/build" --bindir="/usr/src/ffmpeg/bin" --enable-static --disable-opencl \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf x264-snapshot* \
  # libfdk-aac
  && git clone https://github.com/mstorsjo/fdk-aac.git \
  && cd fdk-aac && git checkout tags/v$FDKAAC_VERSION \
  && autoreconf -fiv \
  && ./configure --prefix="/usr/src/ffmpeg/build" --disable-shared \
  && make -j"$(nproc)" \
  && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf mstorsjo-fdk-aac* \
  # libx265
  && wget -O x265.tar.gz https://bitbucket.org/multicoreware/x265/downloads/x265_$LIBX265_VERSION.tar.gz \
  && tar xzvf x265.tar.gz \
  && cd x265_*/build/linux \
  && PATH="/usr/src/ffmpeg/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/usr/src/ffmpeg/build" -DENABLE_SHARED:bool=off ../../source \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf x265 \
  # HandbrakeCli
  && git clone https://github.com/HandBrake/HandBrake.git \
  && cd HandBrake && git checkout tags/$HANDBRAKE_VERSION \
  && ./configure --launch-jobs=$(nproc) --disable-gtk --launch \
  && cd build && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf HandBrake \
  # FFmpeg
  && wget -O ffmpeg.zip https://github.com/FFmpeg/FFmpeg/archive/n$FFMPEG_VERSION.zip \
  && unzip ffmpeg.zip \
  && mv FFmpeg* ffmpeg_src \
  && cd ffmpeg_src \
  && PATH="/usr/src/ffmpeg/bin:$PATH" PKG_CONFIG_PATH="/usr/src/ffmpeg/build/lib/pkgconfig" ./configure \
  --prefix="/usr/src/ffmpeg/build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I/usr/src/ffmpeg/build/include" \
  --extra-ldflags="-L/usr/src/ffmpeg/build/lib" \
  --bindir="/usr/src/ffmpeg/bin" \
  --extra-libs=-lpthread \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && hash -r \
  && cd / \
  && mv /usr/src/ffmpeg/bin/ff* /usr/local/bin \
  && rm -rf /usr/src/ffmpeg

RUN set -ex \
  # Install application dependencies
  && apt-get purge -y --auto-remove $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && gem install video_transcoding \
  && npm install batch-transcode-video -g \
  && mkdir /data

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*