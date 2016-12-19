# where I put stuff
export SOFTWARE_BASE=/home/hawc/hawc_software
# ape stuff
export APERC="$SOFTWARE_BASE/externals/aperc_2.02.02"
eval `$SOFTWARE_BASE/externals/ape-hawc-2.02.02/ape sh externals`
# aerie stuff
eval `$SOFTWARE_BASE/aerie/install/bin/hawc-config --env-sh`
# configuration stuff
export CONFIG_HAWC=$SOFTWARE_BASE/config-hawc
