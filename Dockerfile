ARG HEASOFT_VERSION

FROM ghcr.io/astral-sh/uv:debian-slim AS base

# Install HEASoft prerequisites
ENV DEBIAN_FRONTEND=noninteractive 
ENV UV_PROJECT_ENVIRONMENT=/home/python HEASOFT=/home/heasoft
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && \
	apt-get install -y --no-install-recommends \
    curl \
    gcc \
	gfortran \
	g++ \
	libcurl4 \
	libcurl4-gnutls-dev \
    libdevel-checklib-perl \
	libfile-which-perl \
    libgsl-dev \
    libncurses5-dev \
	libreadline6-dev \
	make \
	ncurses-dev \
	perl-modules \
	vim \
	xorg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync -p 3.12 --locked

FROM base AS heasoft_builder

ARG HEASOFT_VERSION

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran PYTHON=${UV_PROJECT_ENVIRONMENT}/bin/python
RUN unset CFLAGS CXXFLAGS FFLAGS LDFLAGS build_alias host_alias

# Retrieve the HEASoft source code, unpack, configure,
# make, install, clean up, and create symlinks....
ADD heasoft-${HEASOFT_VERSION}src.tar.gz .
WORKDIR /heasoft-${HEASOFT_VERSION}/BUILD_DIR/

RUN ./configure --prefix=${HEASOFT} 2>&1
RUN make 2>&1
RUN make install 2>&1
RUN /bin/bash -c 'cd ${HEASOFT}; for loop in *64*/*; do ln -sf $loop; done' \
    && /bin/bash -c 'cd ${HEASOFT}bin; if test -f /heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc; then cp /heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc .; fi' \
    && /bin/bash -c 'if test -f /heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; then rm -rf /heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; fi' \
    && cd ${HEASOFT}/bin \
    && ln -sf ../BUILD_DIR/Makefile-std

FROM base AS final

ARG HEASOFT_VERSION

LABEL version="${HEASOFT_VERSION}" \
      description="HEASoft ${HEASOFT_VERSION} https://heasarc.gsfc.nasa.gov/lheasoft/" \
      maintainer="Bojan Todorkov"

COPY --from=heasoft_builder ${HEASOFT} ${HEASOFT}

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran \
    PERLLIB=${HEASOFT}/lib/perl \
    PERL5LIB=${HEASOFT}/lib/perl \
    PYTHONPATH=${HEASOFT}/lib/python:${HEASOFT}/lib \
    PATH=${UV_PROJECT_ENVIRONMENT}/bin:${HEASOFT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HEADAS=${HEASOFT} \
    LHEASOFT=${HEASOFT} \
    FTOOLS=${HEASOFT} \
    LD_LIBRARY_PATH=${HEASOFT}/lib \
    LHEAPERL=/usr/bin/perl \
    PFCLOBBER=1 \
    PFILES=/home/pfiles;${HEASOFT}/syspfiles \
    FTOOLSINPUT=stdin \
    FTOOLSOUTPUT=stdout \
    LHEA_DATA=${HEASOFT}/refdata \
    LHEA_HELP=${HEASOFT}/help \
    EXT=lnx \
    PGPLOT_FONT=${HEASOFT}/lib/grfont.dat \
    PGPLOT_RGB=${HEASOFT}/lib/rgb.txt \
    PGPLOT_DIR=${HEASOFT}/lib \
    POW_LIBRARY=${HEASOFT}/lib/pow \
    XRDEFAULTS=${HEASOFT}/xrdefaults \
    TCLRL_LIBDIR=${HEASOFT}/lib \
    XANADU=${HEASOFT} \
    XANBIN=${HEASOFT}

RUN mkdir /home/pfiles
SHELL ["/bin/bash", "-c"]
