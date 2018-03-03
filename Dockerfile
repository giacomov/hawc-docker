FROM condaforge/linux-anvil:root

MAINTAINER Giacomo Vianello <giacomov@stanford.edu>

USER root
ENV USER='root'

# Of course we do not want the password to download Externals in the Dockerfile. You need to
# pass it as argument to docker build, using --build-arg hawcpasswd="[passwd]"
ARG hawcpasswd

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Update repositories and install needed packages
# I use one long line so that I can remove all .deb files at the end
# before Docker writes out this layer

RUN yum install svn -y

##############################
#       AERIE BUILD
##############################

# Setup for build

ENV SOFTWARE_BASE=/hawc_software

# Make directories for aerie

RUN mkdir -p $SOFTWARE_BASE/externals/ && mkdir -p $SOFTWARE_BASE/externals/tmp

# Copy aperc (APE configuration)
COPY aperc_2.06.00 $SOFTWARE_BASE/externals/

# Set the aperc
ENV APERC=/hawc_software/externals/aperc_2.06.00

# Get APE
RUN cd ${SOFTWARE_BASE}/externals && curl https://devel.auger.unam.mx/trac/projects/ape/downloads/75 --output ape-hawc-2.06.00.tar.bz2

# Unpack ape, remove archive, run ape to install externals, then remove downloaded 
# archives to save space

RUN cd ${SOFTWARE_BASE}/externals && \ 
    tar xf ape-hawc-2.06.00.tar.bz2 && \
    rm -rf ape-hawc-2.06.00.tar.bz2 && \
    cd ape-hawc-2.06.00 && \
    echo $hawcpasswd | ./ape --rc=$APERC fetch externals


# Install conda packages and build externals
ENV PATH=/opt/conda/bin:${PATH}
RUN echo $PATH
RUN conda create --name test_env -y python=2.7 numpy scipy ipython root5=5.34.36=py27_3 boost=1.63 fftw gsl xerces-c cmake cfitsio toolchain
ENV PATH=/opt/rh/devtoolset-2/root/usr/bin:${PATH}
RUN unset PYTHONPATH && \
    source activate test_env && \
    which python && \
    which g++ && \
    echo "exit()" | root -b && \
    cd ${SOFTWARE_BASE}/externals && \ 
    export CXXFLAGS="-DBOOST_MATH_DISABLE_FLOAT128 -m64 -I${CONDA_PREFIX}/include" && \
    export CFLAGS="-m64 -I${CONDA_PREFIX}/include" && \
    export LDFLAGS="-Wl,-rpath,${CONDA_PREFIX}/lib -L${CONDA_PREFIX}/lib" && \
    cd ${SOFTWARE_BASE}/externals/ape-hawc-2.06.00 && \
    ./ape --verbose --no-keep --rc=$APERC install externals && \
    rm -rf /hawc_software/externals/ape-hawc-2.06.00/distfiles/*

# Get calibration files
RUN cd ${SOFTWARE_BASE} && svn co https://private.hawc-observatory.org/svn/hawc/workspaces/config-hawc/ --username hawc --password ${hawcpasswd} --non-interactive
ENV CONFIG_HAWC=/hawc_software/config-hawc


# Get the AERIE source code, unpack it then remove the archive, then run installation (configure, make, test, install)
# then remove build and src directories
# This is all one command to stay in one layer (gaining a lot in terms of the size
# of the final image)
RUN source activate test_env && \
    cd ${SOFTWARE_BASE} && \
    svn co https://private.hawc-observatory.org/svn/hawc/workspaces/aerie/trunk --username hawc --password ${hawcpasswd} --non-interactive && \
    cd $SOFTWARE_BASE/trunk/build && \
    eval `$SOFTWARE_BASE/externals/ape-hawc-2.06.00/ape sh externals` && \
    export CXXFLAGS="-DBOOST_MATH_DISABLE_FLOAT128 -m64 -I${CONDA_PREFIX}/include" && \
    export CFLAGS="-m64 -I${CONDA_PREFIX}/include" && \
    export LDFLAGS="-Wl,-rpath,${CONDA_PREFIX}/lib -L${CONDA_PREFIX}/lib" && \
    cmake -DCMAKE_INSTALL_PREFIX=../install -DCMAKE_BUILD_TYPE=Release -DENABLE_CXX11=OFF ../src -Wno-dev -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} -Wl,--no-as-needed" -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} -Wl,--no-as-needed" && \
    make -j 8 && \
    make test CTEST_OUTPUT_ON_FAILURE=TRUE && \
    make install && \
    rm -rf ${SOFTWARE_BASE}/trunk/src && \
    rm -rf ${SOFTWARE_BASE}/aerie/build  

# Setup environment
COPY config_hawc.sh ${SOFTWARE_BASE}

# Copy test data
RUN mkdir -p /hawc_test_data
COPY simulated_data/maptree_256.root /hawc_test_data
COPY simulated_data/detector_response.root /hawc_test_data
ENV HAWC_3ML_TEST_DATA_DIR=/hawc_test_data

# Now make everything accessible by everybody
RUN chmod --recursive a+rwx ${SOFTWARE_BASE} && chmod --recursive a+rwx /hawc_test_data


RUN conda clean -a -y
RUN rm -rf /opt/conda/pkgs/*
WORKDIR /

