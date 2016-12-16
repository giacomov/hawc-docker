export nside=256

skymaps-maptree2fits -i maptree_1024.root -o _map -n 10 -f 0

for map in $(ls _map*); do aerie-apps-combine-maps --inputs $map -o ${nside}_${map} -d ${nside}  ; done

skymaps-fits2maptree --input ${nside}__map* -o maptree_${nside}.root
