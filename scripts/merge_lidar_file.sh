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
    *)
    echo "Unknown option: $i"
    exit 1
    ;;
esac
done


subtract_4digit() {
    local a="$1"
    local b="$2"

    # Convert to base-10 to avoid octal issues
    local result=$((10#$a - 10#$b))

    # Optional: clamp negative result to 0
    if (( result < 0 )); then
        result=0
    fi
    
    # Print zero-padded 4-digit result
    printf "%04d\n" "$result"
}

add_4digit() {
    local a="$1"
    local b="$2"

    # Convert to base-10 to avoid octal issues
    local result=$((10#$a + 10#$b))

    # Print zero-padded 4-digit result
    printf "%04d\n" "$result"
}


# Créer le répertoire de sortie s'il n'existe pas
mkdir -p "$output_dir"



# Fonction pour traiter chaque fichier
process_file() {
  file=$1
  filename=$(basename "$file")
  base_dir=$(dirname "$file")
  
  # Utilise une expression régulière pour extraire les parties
  if [[ "$filename" =~ ^(.*\.copc_)([0-9]+)_([0-9]+)_(.+)$ ]]; then
    PREFIX="${BASH_REMATCH[1]}"
    xx="${BASH_REMATCH[2]}"
    yy="${BASH_REMATCH[3]}"
    POSTFIX="${BASH_REMATCH[4]}"
    numbers=($(echo "$filename" | grep -oE '[0-9]+' | head -n 2))
    TX=${numbers[0]}
    TY=${numbers[1]}
    # echo "$filename"
    # echo "PREFIX: $PREFIX"
    # echo "TX : $TX"
    # echo "TY : $TY"
    # echo "X: $xx"
    # echo "Y: $yy"
    # echo "POSTFIX: $POSTFIX"
  else
    echo "Le nom de fichier ne correspond pas au format attendu."
  fi

  # Définir les offsets voisins (-1, 0, +1)
  neighbors=()
  #echo "-----------------------------------------------------------"
  is_bound="false"
  for dx in -2 -1 0 1 2; do
    for dy in -2 -1 0 1 2; do
      nx=$((xx + dx))
      ny=$((yy + dy))
      NTX=$TX
      NTY=$TY
      #echo "$dx $dy $nx $ny"
      if (( $nx < 0 )); then
	mod=$(( (${nx} % 50 + 50) %50))
	nx=${mod}
	NTX=$(subtract_4digit ${TX}  1)
	is_bound="true"
      fi
      if (( $ny < 0 )); then
	mod=$(( (${ny} % 50 + 50) %50))
	ny=${mod}
	NTY=$(subtract_4digit ${TY}  1)
	is_bound="true"	
      fi
      if (( $nx > 49 )); then
	mod=$(( (${nx} % 50 + 50) %50))
	nx=${mod}
	NTX=$(add_4digit  ${TX}  1)
	is_bound="true"	
      fi
      if (( $ny > 49 )); then
	mod=$(( (${ny} % 50 + 50) %50))
	ny=${mod}
	NTY=$(add_4digit ${TY}  1)
	is_bound="true"	
      fi
     
      NPREFIX="LHD_FXX_${NTX}_${NTY}_PTS_O_LAMB93_IGN69.copc_${nx}_${ny}_${POSTFIX}"
      # if [ "$TX" = "0657f" ]; 
      # then
      # 	if [ "$xx" = "0" ]; 
      # 	then
      # 	  echo "x:$xx y:$yy nx:$nx ny:$ny dx:$dx dy:$dy TX:$TX TY:$TY NTX:$NTX NTY:$NTY"
      # 	  echo "old:${PREFIX}${pos}${xx}_${yy}_${POSTFIX}"
      # 	  echo "new:${NPREFIX}"
      # 	  echo ""
      # 	fi
      # fi
      #neighbors+=("${nx}_${ny}")      
      neighbors+=("${NPREFIX}")      
    done
  done
  # if [ "$is_bound" = "false" ]; then
  #   return 0
  # fi

  # Construire la liste des fichiers voisins existants
  input_files=()
  for pos in "${neighbors[@]}"; do
    #match=$(find "$base_dir" -type f -name "${PREFIX}${pos}_*${POSTFIX}")
    match=$(find "$base_dir" -type f -name "${pos}")
    # echo "===> match <===="
    # echo $match
    readarray -t match2 <<< "$(echo "$match" | tr -s '[:space:]' '\n')"
    if [[ -n "$match" ]]; then
      input_files+=( "${match2[@]}" )
    fi
  done

  # if [[ ${#input_files[@]} -ne 25 ]]; then
  #   echo "input_file != 25 x:$xx y:$yy  TX:$TX TY:$TY "
  #   return 0
  # fi
  
  # echo "========="
  # echo "${input_files[@]}"
  # echo "========="
  
  # Créer la commande PDAL
  output_file="${output_dir}/${PREFIX}${xx}_${yy}_${POSTFIX}"
  # Construction propre du tableau JSON
  json_inputs=$(printf '"%s",' "${input_files[@]}")
  json_inputs="[${json_inputs%,}]"  # Supprimer la dernière virgule

  # Construction du tableau JSON avec readers.las explicites
  readers_json=""
  for file in "${input_files[@]}"; do
    readers_json+="
    { \"type\": \"readers.las\", \"filename\": \"${file}\" },"
  done
  # Retirer la dernière virgule
  readers_json=${readers_json%,}
  #echo "$readers_json"
  # Construction complète du pipeline
  pipeline=$(mktemp)
  cat > "$pipeline" <<EOF
{
  "pipeline": [
    ${readers_json},
    {
      "type": "writers.las",
      "filename": "${output_file}"
    }
  ]
}
EOF

  # Lancer le pipeline
  pdal pipeline "$pipeline"

  # Nettoyer
  rm "$pipeline"


  stat_file="${output_file%.laz}.txt"
  pdal info --metadata $output_file > ${stat_file}
}

export -f process_file
export output_dir

# Limiter le nombre de processus en arrière-plan
# Get the total number of CPU cores
total_cores=$(nproc)
max_jobs=$((total_cores - 1))

count=0

for file in "${input_dir}"/*.laz; do
  process_file "$file" &
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
