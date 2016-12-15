FROM ubuntu:16.04

MAINTAINER Giacomo Vianello <giacomov@stanford.edu>

# Explicitly become root (even though likely we are root already)
USER root

# Override the default shell (sh) with bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Update repositories and install packages
RUN apt-get update && apt-get install -y python2.7 python2.7-dev curl git subversion git build-essential bzip2 libbz2-dev

#Create link for python
RUN ln -s /usr/bin/python2.7 /usr/bin/python

# Install dependencies for ROOT
RUN apt-get install -y dpkg-dev cmake binutils libpng12-dev libjpeg-dev gfortran libssl-dev libfftw3-dev libcfitsio-dev python-dev libgsl0-dev libx11-dev libxpm-dev libxft-dev libxext-dev

# Create user hawc
RUN groupadd -r hawc -g 433
RUN useradd -u 431 -r -g hawc -s /bin/bash -c "hawc user" hawc
RUN mkdir -p /home/hawc
RUN chown -R hawc:hawc /home/hawc

# ROOT look for libraries in some pre-defined paths, which unfortunately
# do not exist on Ubuntu. This trick solves the problem by creating /usr/lib64
# which usually does not exist and linking it to where the libraries live in Ubuntu 
RUN ln -s /usr/lib/x86_64-linux-gnu /usr/lib64 

# Become the hawc user, so the build is not owned by root 
USER hawc

##############################
#       AERIE BUILD
##############################

# Setup for build
ENV SOFTWARE_BASE=/home/hawc/hawc_software

RUN mkdir -p $SOFTWARE_BASE/externals/
RUN mkdir -p $SOFTWARE_BASE/externals/tmp

# Copy the AERIE code from the host
COPY ape-hawc-2.02.02.tar.bz2 /home/hawc/hawc_software/externals/
COPY aperc_2.02.02 /home/hawc/hawc_software/externals/

RUN cd $SOFTWARE_BASE/externals/ && tar xf ape-hawc-2.02.02.tar.bz2

ENV APERC=/home/hawc/hawc_software/externals/aperc_2.02.02

# Of course we do not want the password in the Dockerfile. You need to
# pass it as argument to docker build, using -build-arg hawcpasswd="[passwd]"
ARG hawcpasswd
RUN cd $SOFTWARE_BASE/externals/ape-hawc-2.02.02 && echo $hawcpasswd | ./ape --verbose --no-keep --rc=$APERC install externals

# Remove APE tar file
RUN cd $SOFTWARE_BASE/externals/ && rm -rf ape-hawc-2.02.02.tar.bz2

# Get the AERIE source code
COPY aerie.tar.gz /home/hawc/hawc_software/
RUN cd /home/hawc/hawc_software/ && tar xf aerie.tar.gz
RUN cd /home/hawc/hawc_software/ && rm -rf aerie.tar.gz

# Build AERIE
RUN cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals` && cmake -DCMAKE_INSTALL_PREFIX=../install -DCMAKE_BUILD_TYPE=Release -DENABLE_CXX11=ON ../src -Wno-dev -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" 
RUN cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals` && make -j 4 

# Copy calibration files
COPY config-hawc.tar.gz /home/hawc/hawc_software/
RUN cd /home/hawc/hawc_software/ && tar xf config-hawc.tar.gz && rm -rf config-hawc.tar.gz
ENV CONFIG_HAWC=/home/hawc/hawc_software/config-hawc

# Become root again to install python
USER root
# Install pythn packages
RUN apt-get install -y python-pip
RUN pip install numpy scipy ipython
USER hawc

# Run tests 
RUN cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals` && make test CTEST_OUTPUT_ON_FAILURE=TRUE 

# Install AERIE 
RUN cd $SOFTWARE_BASE/aerie/build && eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals` && make install

# Setup environment
COPY bashrc /home/hawc/.bashrc

# Clean up to reduce the size of the container
RUN rm -rf /home/hawc/hawc_software/aerie/src
RUN rm -rf /home/hawc/hawc_software/aerie/build/
RUN rm -rf /home/hawc/hawc_software/externals/ape-hawc-2.02.02/distfiles/*
USER root
RUN apt-get purge
USER hawc

# Create workdir
RUN mkdir /home/hawc/workdir

# Set it as workdir
WORKDIR /home/hawc/workdir
