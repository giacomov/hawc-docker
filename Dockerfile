FROM ubuntu:16.04

MAINTAINER Giacomo Vianello <giacomov@stanford.edu>

# Of course we do not want the password to download Externals in the Dockerfile. You need to
# pass it as argument to docker build, using -build-arg hawcpasswd="[passwd]"
ARG hawcpasswd

# Explicitly become root (even though likely we are root already)
USER root

# Override the default shell (sh) with bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Update repositories and install needed packages
# I use one long line so that I can remove all .deb files at the end
# before Docker writes out this layer

RUN apt-get update && apt-get install -y python2.7 python2.7-dev curl git subversion git build-essential bzip2 libbz2-dev dpkg-dev cmake binutils libpng12-dev libjpeg-dev gfortran libssl-dev libfftw3-dev libcfitsio-dev python-dev libgsl0-dev libx11-dev libxpm-dev libxft-dev libxext-dev python-pip python-tk && apt-get clean 

# Install python packages needed by the tests of AERIE

RUN pip install --no-cache-dir numpy scipy ipython

# Create user hawc

RUN groupadd -r hawc -g 433 && useradd -u 431 -r -g hawc -s /bin/bash -c "hawc user" hawc
RUN mkdir -p /home/hawc && chown -R hawc:hawc /home/hawc

# ROOT look for libraries in some pre-defined paths, which unfortunately
# do not exist on Ubuntu. This trick solves the problem by liking the place
# where libraries live in Ubuntu (/usr/lib/x86_64-linux-gnu) to where ROOT
# expects them (/usr/lib64) 

RUN ln -s /usr/lib/x86_64-linux-gnu /usr/lib64 

# Become the hawc user, so the build is not owned by root 
USER hawc

##############################
#       AERIE BUILD
##############################

# Setup for build

ENV SOFTWARE_BASE=/home/hawc/hawc_software

# Make directories for aerie

RUN mkdir -p $SOFTWARE_BASE/externals/ && mkdir -p $SOFTWARE_BASE/externals/tmp

# Copy aperc (APE configuration)
COPY aperc_2.02.02 /home/hawc/hawc_software/externals/

# Set the aperc
ENV APERC=/home/hawc/hawc_software/externals/aperc_2.02.02

# Copy the AERIE code from the host

COPY ape-hawc-2.02.02.tar.bz2 /home/hawc/hawc_software/externals/ 

# Unpack ape, remove archive, run ape to install externals, then remove downloaded 
# archives to save space
RUN cd $SOFTWARE_BASE/externals/ && tar xf ape-hawc-2.02.02.tar.bz2 && rm -rf ape-hawc-2.02.02.tar.bz2 && cd $SOFTWARE_BASE/externals/ape-hawc-2.02.02 && echo $hawcpasswd | ./ape --verbose --no-keep --rc=$APERC install externals && rm -rf /home/hawc/hawc_software/externals/ape-hawc-2.02.02/distfiles/*

# Copy calibration files
COPY config-hawc.tar.gz /home/hawc/hawc_software/
RUN cd /home/hawc/hawc_software/ && tar xf config-hawc.tar.gz && rm -rf config-hawc.tar.gz
ENV CONFIG_HAWC=/home/hawc/hawc_software/config-hawc


# Get the AERIE source code, unpack it then remove the archive, then run installation (configure, make, test, install)
# then remove build and src directories
# This is all one command to stay in one layer (gaining a lot in terms of the size
# of the final image)
COPY aerie.tar.gz /home/hawc/hawc_software/
RUN cd /home/hawc/hawc_software/ && tar xf aerie.tar.gz && rm -rf aerie.tar.gz && cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals` && cmake -DCMAKE_INSTALL_PREFIX=../install -DCMAKE_BUILD_TYPE=Release -DENABLE_CXX11=ON ../src -Wno-dev -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" && make -j 4 && make test CTEST_OUTPUT_ON_FAILURE=TRUE && make install && rm -rf /home/hawc/hawc_software/aerie/src && rm -rf /home/hawc/hawc_software/aerie/build  

# Setup environment
COPY bashrc /home/hawc/.bashrc

# Copy test data
RUN mkdir -p /home/hawc/hawc_test_data
COPY simulated_data/maptree_256.root /home/hawc/hawc_test_data
COPY simulated_data/detector_response.root /home/hawc/hawc_test_data
ENV HAWC_3ML_TEST_DATA_DIR=/home/hawc/hawc_test_data

# Create workdir
RUN mkdir /home/hawc/workdir

# Set it as workdir
WORKDIR /home/hawc/workdir
