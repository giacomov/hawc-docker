# where I put stuff
export SOFTWARE_BASE=/hawc_software
# ape stuff
export APERC="$SOFTWARE_BASE/externals/aperc_2.06.00"
eval `$SOFTWARE_BASE/externals/ape-hawc-2.06.00/ape sh externals`
# aerie stuff
eval `$SOFTWARE_BASE/trunk/install/bin/hawc-config --env-sh`
# configuration stuff
export CONFIG_HAWC=$SOFTWARE_BASE/config-hawc
