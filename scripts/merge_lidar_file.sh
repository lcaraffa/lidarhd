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
    x="${BASH_REMATCH[2]}"
    y="${BASH_REMATCH[3]}"
    POSTFIX="${BASH_REMATCH[4]}"
    echo "PREFIX: $PREFIX"
    echo "X: $x"
    echo "Y: $y"
    echo "POSTFIX: $POSTFIX"
  else
    echo "Le nom de fichier ne correspond pas au format attendu."
  fi

  # Définir les offsets voisins (-1, 0, +1)
  neighbors=()
  for dx in -2 -1 0 1 2; do
    for dy in -2 -1 0 1 2; do
      nx=$((x + dx))
      ny=$((y + dy))
      neighbors+=("${nx}_${ny}")
    done
  done

  # Construire la liste des fichiers voisins existants
  input_files=()
  for pos in "${neighbors[@]}"; do
    #echo "$pos"
    match=$(find "$base_dir" -type f -name "${PREFIX}${pos}_*${POSTFIX}")
    readarray -t match2 <<< "$(echo "$match" | tr -s '[:space:]' '\n')"

    if [[ -n "$match" ]]; then
      input_files+=( "${match2[@]}" )
    fi
  done

    # echo "========="
    # echo "${input_files[@]}"
    # echo "========="
  
  # Créer la commande PDAL
  output_file="${output_dir}/merged_${x}_${y}_${POSTFIX}"
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
