#!/bin/bash

# Default power of 2 for tiling
pow=3
subsample_ratio=0.2

# Parse command-line arguments
for i in "$@"
do
case $i in
    --input_dir=*)
    input_dir="${i#*=}"
    shift
    ;;
    --output_dir=*)
    output_dir="${i#*=}"
    shift
    ;;
    --chunk_size=*)
    chunk_size="${i#*=}"
    shift
    ;;
    --min_x=*)
    glob_x_min="${i#*=}"
    shift
    ;;
    --min_y=*)
    glob_y_min="${i#*=}"
    shift
    ;;    
    --subsample_ratio=*)
    subsample_ratio="${i#*=}"
    shift
    ;;
    *)
    echo "Unknown option: $i"
    exit 1
    ;;
esac
done

total_cores=$(nproc)
max_jobs=$((total_cores - 1))

count=0


# Créer le répertoire de sortie s'il n'existe pas
mkdir -p "$output_dir"

# Fonction pour traiter chaque fichier
process_file_1() {
  file=$1
  echo "Processing1: $file"
  
  temp_info=$(mktemp)
  pdal info --metadata "$file" > "$temp_info"
  
  x_min=$(grep -oP '"minx":\s*\K\d+' "$temp_info")
  x_max=$(grep -oP '"maxx":\s*\K\d+' "$temp_info")
  y_min=$(grep -oP '"miny":\s*\K\d+' "$temp_info")
  y_max=$(grep -oP '"maxy":\s*\K\d+' "$temp_info")
  
  rm "$temp_info"
  
  #num_tiles=$((2 ** pow))
  tile_size_x=${chunk_size} # $(python3 -c "print(($x_max - $x_min) / $num_tiles)")

  output_file="${output_dir}/$(basename "$file" .laz)_#.laz"
  pdal tile -i "$file" -o "$output_file" --length "$tile_size_x" --origin_x "$x_min" --origin_y "$y_min"
}

export -f process_file_1
export output_dir
export pow

for file in "$input_dir"/*.laz; do
  process_file_1 "$file" &
  count=$((count + 1))
  
  if [[ $count -ge $max_jobs ]]; then
    wait -n
    count=$((count - 1))
  fi

done
wait


# Fonction pour traiter chaque fichier
process_file_2() {
  file=$1
  echo $file
  temp_info=$(mktemp)
  pdal info --all --input "$file" > "${temp_info}"
  nn=$(grep -n "PointSourceId" "${temp_info}" | awk -F: 'NR==3 {print $1}')

  # Calculer les numéros de ligne pour -1 et -2
  line_minus_1=$(($nn - 1))
  line_minus_2=$(($nn - 2))

  # Extraire max_id et min_id
  max_id=$(sed -n "${line_minus_2}p" "$temp_info" | sed -n 's/.*"maximum": \([0-9]\+\).*/\1/p')
  min_id=$(sed -n "${line_minus_1}p" "$temp_info" | sed -n 's/.*"minimum": \([0-9]\+\).*/\1/p')

  # Vérifier si min_id et max_id sont définis
  if [[ -z "$min_id" || -z "$max_id" ]]; then
    echo "Error: min_id or max_id is not defined."
    exit 1
  fi

  for ((id=$min_id; id<=$max_id; id++)); do
    output_file="${output_dir}/$(basename "$file" .laz)_${id}.laz"
    echo $output_file
    temp_pipeline=$(mktemp)
    echo '{
               "pipeline": [' > "$temp_pipeline"

    # Ajouter le fichier .laz actuel au pipeline
    echo '    {
                 "type": "readers.las",
                    "filename": "'"$file"'"
          },' >>    "$temp_pipeline"
    cat >> "$temp_pipeline" <<EOF
        {
            "type": "filters.transformation",
            "matrix": "1 0 0 -${glob_x_min}  0 1 0 -${glob_y_min}  0 0 1 0  0 0 0 1"
        },
        {
          "type": "filters.range",
          "limits": "PointSourceId[$id:$id]"
        },
        {
         "type": "writers.las",
         "filename": "$output_file",
         "compression": "laszip"
        }
      ]
    }
EOF
    # Exécuter le pipeline PDAL
    pdal pipeline "$temp_pipeline"
    rm "$temp_pipeline"
  done
  rm "$file"
}

export -f process_file_2
export output_dir
export glob_x_min
export glob_y_min

# Limiter le nombre de processus en arrière-plan
# Get the total number of CPU cores


for file in "${output_dir}"/*.laz; do
  process_file_2 "$file" &
  count=$((count + 1))

  # Attendre si le nombre maximum de tâches est atteint
  if [[ $count -ge $max_jobs ]]; then
    wait -n
    count=$((count - 1))
  fi
done

# Attendre la fin de toutes les tâches en arrière-plan
wait

exit 0
