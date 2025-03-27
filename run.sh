#!/bin/bash
source ./common.sh

usage() {
  echo "Usage: $0 --list_files <txt_file> --project_path <project_path>"
  exit 1
}

POW=3
BBOX_SIZE=100
DO_CROP=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
      --list_files) LIST_FILES="$2"; shift ;;
      --bbox_size) BBOX_SIZE="$2"; shift ;;
      --pow) POW="$2"; shift ;;
      --center) CENTER_FILE="$2"; shift ;;      
      --do_crop) DO_CROP=true ;;
      --project_path) PROJECT_PATH="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

[ -z "$LIST_FILES" ] || [ -z "$PROJECT_PATH" ] && { echo "Error." ; usage ; }

# Afficher un résumé des paramètres
echo "Résumé des paramètres:"
echo "  - Fichier list_files  : $LIST_FILES"
echo "  - Fichier center      : ${CENTER_FILE:-Non spécifié}"
echo "  - Taille BBOX         : $BBOX_SIZE"
echo "  - Do_CROP         : $BBOX_SIZE"
echo "  - Chemin projet       : $PROJECT_PATH"

RAW_LAZ_DIR=${PROJECT_PATH}/raw_inputs

log "download ..." "$PROCESS"
mkdir -p ${RAW_LAZ_DIR}/inputs
while IFS= read -r line; do
    FILENAME=$(basename "${line}")
    FILEPATH=${RAW_LAZ_DIR}/${FILENAME}
    if [ ! -e "${FILEPATH}" ]; then
	wget -O ${FILEPATH}  ${line}
    fi
done < "${LIST_FILES}"


log "compute stats ..." "$PROCESS"
INPUT_DIR=${RAW_LAZ_DIR}
STATS_DIR=${PROJECT_PATH}/stats
if [ -d "${STATS_DIR}" ]; then
    log "${STATS_DIR} exists, skip crop!" "$SKIP"
else
    mkdir -p ${STATS_DIR}

    read -r LAT LONG < ${CENTER_FILE}
    log "Stats /data/scripts/tile_lidar_files.sh"
    CMD="/data/scripts/compute_stats.sh --input_dir=${INPUT_DIR} --output_dir=${STATS_DIR}"
    echo "=> $CMD"
    docker run --rm -v ${PROJECT_PATH}:${PROJECT_PATH} \
           -v ${PWD}/scripts:/data/scripts \
           pdal/pdal \
           /bin/bash -c "${CMD}"
fi
## Compute min 
read MIN_X MIN_Y <<< $(find ${STATS_DIR} -name "*.txt" -exec awk '{print $1, $2}' {} + | \
			 awk 'BEGIN {min1=9999999; min2=9999999} {if ($1 < min1) min1=$1} {if ($2 < min2) min2=$2} END {print min1, min2}')
log "MIN_X: $MIN_X, MIN_Y: $MIN_Y"
log "stats finished!" "$FINISH"


if [[ "$DO_CROP" == "true" ]]; then
  log "crop ..." "$PROCESS"
  CROPED_DIR=${PROJECT_PATH}/croped
  INPUT_DIR=${RAW_LAZ_DIR}
  if [ -d "${CROPED_DIR}" ]; then
    log "${CROPED_DIR} exists, skip crop!" "$SKIP"
  else
    mkdir -p ${CROPED_DIR}
    if [ -n "${BBOX_SIZE}" ]; then
      BBOX_SIZE_CMD="--bbox_size=${BBOX_SIZE}"
    else
      BBOX_SIZE_CMD=""
    fi

    if [ -n "${subsample_ratio}" ]; then
      SUBSAMPLE_RATIO_CMD="--subsample_ratio=${subsample_ratio}"
    else
      SUBSAMPLE_RATIO_CMD=""
    fi

    read -r LAT LONG < ${CENTER_FILE}
    CMD="/data/scripts/crop_lidar_files.sh --input_dir=${RAW_LAZ_DIR} --output_file=${CROPED_DIR}/cropped_merged.laz --LAT=${LAT} --LONG=${LONG} ${BBOX_SIZE_CMD} ${SUBSAMPLE_RATIO_CMD}"
    log "Start ${CMD}" "$PROCESS"
    docker run --rm -v ${PROJECT_PATH}:${PROJECT_PATH} \
           -v ${PWD}/scripts:/data/scripts \
           pdal/pdal \
           /bin/bash -c "${CMD}"
  fi
  log "cropping finished!" "$FINISH"
fi


log "tiling ..." "$PROCESS"
if [[ "$DO_CROP" == "false" ]]; then
  INPUT_DIR=${RAW_LAZ_DIR}
else
  INPUT_DIR=${CROPED_DIR}
fi
PROCESSED_DIR=${PROJECT_PATH}/processed
if [ -d "${PROCESSED_DIR}" ]; then
    log "${PROCESSED_DIR} exists, skip crop!" "$SKIP"
else
    mkdir -p ${PROCESSED_DIR}
    CMD="/data/scripts/tile_lidar_files.sh --input_dir=${INPUT_DIR} --output_dir=${PROCESSED_DIR} --min_x=${MIN_X}  --min_y=${MIN_Y} --pow=${POW}"
    log "Start ${CMD}  ..."	       
    docker run --rm -v ${PROJECT_PATH}:${PROJECT_PATH} \
           -v ${PWD}/scripts:/data/scripts \
           pdal/pdal \
           /bin/bash -c "${CMD}"
    # docker run -it -v ${PROJECT_PATH}:${PROJECT_PATH} \
    #        -v ${PWD}/scripts:/data/scripts \
    #        pdal/pdal \
    #        /bin/bash 
fi
log "tiling finished!" "$FINISH"

log "convert to binary ..." "$PROCESS"
BIN_DIR=${PROJECT_PATH}/bin
if [ -d "${BIN_DIR}" ]; then
    log "${BIN_DIR} exists, skip crop!" "$SKIP"
else
  mkdir -p ${BIN_DIR}
  echo "$BIN_DIR"
  ./build/lidarhd_env/bin/python3 scripts/convert_ply.py --input_dir ${PROCESSED_DIR} --output_dir ${BIN_DIR}
fi
log "convert done!" "$FINISH"
