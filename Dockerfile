FROM python:3.12-slim-bookworm AS base

ARG version=6.34
ENV HEASOFT_VERSION=${version}

# Install HEASoft prerequisites
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && \
	apt-get install -y --no-install-recommends \
    gcc \
	gfortran \
	g++ \
	curl \
	libcurl4 \
	libcurl4-gnutls-dev \
	libncurses5-dev \
	libreadline6-dev \
	libfile-which-perl \
	libdevel-checklib-perl \
	make \
	ncurses-dev \
	perl-modules \
	vim \
	xorg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd heasoft && useradd -r -m -g heasoft heasoft \
    && mkdir -p /opt/heasoft \
    && chown -R heasoft:heasoft /opt/heasoft

RUN pip install --upgrade pip && \
    pip install --no-cache-dir astropy numpy scipy matplotlib setuptools

FROM base AS heasoft

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran
RUN unset CFLAGS CXXFLAGS FFLAGS LDFLAGS build_alias host_alias

# Retrieve the HEASoft source code, unpack, configure,
# make, install, clean up, and create symlinks....
ADD --chown=heasoft:heasoft heasoft-${HEASOFT_VERSION}src.tar ./
RUN cd heasoft-${HEASOFT_VERSION}/BUILD_DIR/ \
 && echo "Configuring heasoft..." \
 && ./configure --prefix=/opt/heasoft 2>&1 \
 && echo "Building heasoft..." \
 && make 2>&1 \
 && echo "Installing heasoft..." \
 && make install 2>&1 \
 && /bin/bash -c 'cd /opt/heasoft/; for loop in *64*/*; do ln -sf $loop; done' \
 && /bin/bash -c 'cd /opt/heasoft/bin; if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc; then cp ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc .; fi' \
 && /bin/bash -c 'if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; then rm -rf ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; fi' \
 && cd /opt/heasoft/bin \
 && ln -sf ../BUILD_DIR/Makefile-std

FROM base AS final

LABEL version="${version}" \
      description="HEASoft ${version} https://heasarc.gsfc.nasa.gov/lheasoft/" \
      maintainer="Bojan Todorkov"

COPY --from=heasoft --chown=heasoft:heasoft /opt/heasoft /opt/heasoft

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran \
    PERLLIB=/opt/heasoft/lib/perl \
    PERL5LIB=/opt/heasoft/lib/perl \
    PYTHONPATH=/opt/heasoft/lib/python:/opt/heasoft/lib \
    PATH=/opt/heasoft/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HEADAS=/opt/heasoft \
    LHEASOFT=/opt/heasoft \
    FTOOLS=/opt/heasoft \
    LD_LIBRARY_PATH=/opt/heasoft/lib \
    LHEAPERL=/usr/bin/perl \
    PFCLOBBER=1 \
    PFILES=/home/heasoft/pfiles;/opt/heasoft/syspfiles \
    FTOOLSINPUT=stdin \
    FTOOLSOUTPUT=stdout \
    LHEA_DATA=/opt/heasoft/refdata \
    LHEA_HELP=/opt/heasoft/help \
    EXT=lnx \
    POW_LIBRARY=/opt/heasoft/lib/pow \
    XRDEFAULTS=/opt/heasoft/xrdefaults \
    TCLRL_LIBDIR=/opt/heasoft/lib \
    XANADU=/opt/heasoft \
    XANBIN=/opt/heasoft

USER heasoft
WORKDIR /home/heasoft
RUN mkdir pfiles
