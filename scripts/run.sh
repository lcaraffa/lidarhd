CHANTIER_DIR=/mnt/data1/chantier/pont_du_gard_4t/
docker run --rm -v ${CHANTIER_DIR}:${CHANTIER_DIR} \
                -v ${PWD}:/data/scripts \
                pdal/pdal \
                /bin/bash -c "/data/scripts/crop_lidar_files.sh --input_dir=${CHANTIER_DIR}/inputs/ --output_file=${CHANTIER_DIR}/crop/cropped_merged.laz --LAT=43.947474884775424 --LONG=4.535150954231938"
