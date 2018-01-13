FROM ubuntu:16.04

MAINTAINER Giacomo Vianello <giacomov@stanford.edu>

# Of course we do not want the password to download Externals in the Dockerfile. You need to
# pass it as argument to docker build, using -build-arg hawcpasswd="[passwd]"
ARG hawcpasswd

# Explicitly become root (even though likely we are root already)
USER root
ENV USER=root

# Override the default shell (sh) with bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Update repositories and install needed packages
# I use one long line so that I can remove all .deb files at the end
# before Docker writes out this layer

RUN apt-get update && apt-get install -y python2.7 python2.7-dev curl git subversion git build-essential bzip2 libbz2-dev dpkg-dev cmake binutils libpng12-dev libjpeg-dev gfortran libssl-dev libfftw3-dev libcfitsio-dev python-dev libgsl0-dev libx11-dev libxpm-dev libxft-dev libxext-dev python-pip python-tk && apt-get clean 

# Needed for SSL to work (i.e., all https links and downloads)

RUN mkdir /etc/pki
RUN mkdir /etc/pki/tls
RUN mkdir /etc/pki/tls/certs
RUN apt-get install wget
RUN wget http://curl.haxx.se/ca/cacert.pem
RUN mv cacert.pem ca-bundle.crt
RUN mv ca-bundle.crt /etc/pki/tls/certs

# Install python packages needed by the tests of AERIE

RUN pip install --no-cache-dir numpy scipy 'ipython<6.0' virtualenv


# ROOT look for libraries in some pre-defined paths, which unfortunately
# do not exist on Ubuntu. This trick solves the problem by liking the place
# where libraries live in Ubuntu (/usr/lib/x86_64-linux-gnu) to where ROOT
# expects them (/usr/lib64) 

RUN ln -s /usr/lib/x86_64-linux-gnu /usr/lib64 


##############################
#       AERIE BUILD
##############################

# Setup for build

ENV SOFTWARE_BASE=/hawc_software

# Make directories for aerie

RUN mkdir -p $SOFTWARE_BASE/externals/ && mkdir -p $SOFTWARE_BASE/externals/tmp

# Copy aperc (APE configuration)
COPY aperc_2.06.00 /hawc_software/externals/

# Set the aperc
ENV APERC=/hawc_software/externals/aperc_2.06.00

# Copy the AERIE code from the host

COPY ape-hawc-2.06.00.tar.bz2 /hawc_software/externals/ 

# Unpack ape, remove archive, run ape to install externals, then remove downloaded 
# archives to save space
RUN cd $SOFTWARE_BASE/externals/ && tar xf ape-hawc-2.06.00.tar.bz2 && rm -rf ape-hawc-2.06.00.tar.bz2 && cd $SOFTWARE_BASE/externals/ape-hawc-2.06.00 && echo $hawcpasswd | ./ape --verbose --no-keep --rc=$APERC install externals && rm -rf /hawc_software/externals/ape-hawc-2.06.00/distfiles/*

# Copy calibration files
COPY config-hawc.tar.gz /hawc_software/
RUN cd /hawc_software/ && tar xf config-hawc.tar.gz && rm -rf config-hawc.tar.gz
ENV CONFIG_HAWC=/hawc_software/config-hawc


# Get the AERIE source code, unpack it then remove the archive, then run installation (configure, make, test, install)
# then remove build and src directories
# This is all one command to stay in one layer (gaining a lot in terms of the size
# of the final image)
COPY aerie.tar.gz /hawc_software/
RUN cd /hawc_software/ && tar xf aerie.tar.gz && rm -rf aerie.tar.gz && cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.06.00/ape sh externals` && cmake -DCMAKE_INSTALL_PREFIX=../install -DCMAKE_BUILD_TYPE=Release -DENABLE_CXX11=OFF ../src -Wno-dev -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" && make -j 8 && make test CTEST_OUTPUT_ON_FAILURE=TRUE && make install && rm -rf /hawc_software/aerie/src && rm -rf /hawc_software/aerie/build  

# Setup environment
COPY config_hawc.sh /hawc_software/

# Copy test data
RUN mkdir -p /hawc_test_data
COPY simulated_data/maptree_256.root /hawc_test_data
COPY simulated_data/detector_response.root /hawc_test_data
ENV HAWC_3ML_TEST_DATA_DIR=/hawc_test_data

# Now make everything accessible by everybody
RUN chmod --recursive a+rwx /hawc_software && chmod --recursive a+rwx /hawc_test_data

# Finally install sudo
RUN apt-get install sudo

WORKDIR /

