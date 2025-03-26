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
    --pow=*)
    pow="${i#*=}"
    shift
    ;;
    --min_x=*)
    min_x="${i#*=}"
    shift
    ;;
    --min_y=*)
    min_y="${i#*=}"
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

# Calculate the number of tiles
num_tiles=$((2 ** pow))

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Loop over each .laz file
for file in "$input_dir"/*.laz; do
  # Create a temporary file to list the pipeline for the current file
  temp_pipeline=$(mktemp)

  # Get the bounds of the current file using pdal info and awk
  echo "file: $file"
  x_min=$(pdal info --metadata $file | grep minx  | grep -oP '"minx":\s*\K\d+')
  x_max=$(pdal info --metadata $file | grep maxx  | grep -oP '"maxx":\s*\K\d+')
  y_min=$(pdal info --metadata $file | grep miny  | grep -oP '"miny":\s*\K\d+')
  y_max=$(pdal info --metadata $file | grep maxy  | grep -oP '"maxy":\s*\K\d+')

  # Print the values of the variables
  echo "x_min: $x_min"
  echo "x_max: $x_max"
  echo "y_min: $y_min"
  echo "y_max: $y_max"

  # Calculate the tile size
  tile_size_x=$(python3 -c "print(($x_max - $x_min) / $num_tiles)")
  tile_size_y=$(python3 -c "print(($y_max - $y_min) / $num_tiles)")
  echo "${tile_size_x}"
  echo "${tile_size_y}"

  temp_info=$(mktemp)
  pdal info --all --input $file > ${temp_info}
  nn=$(cat ${temp_info} | grep -n "PointSourceId" | awk -F: 'NR==3 {print $1}')
  cat ${temp_info} | grep -n "PointSourceId"
  echo "nn =>  $nn"

  # Calculer les numéros de ligne pour -1 et -2
  line_minus_1=$(($nn - 1))
  line_minus_2=$(($nn - 2))

  # Print line numbers
  echo "line_minus_1: $line_minus_1"
  echo "line_minus_2: $line_minus_2"
  max_id=$(sed -n "${line_minus_2}p" "$temp_info" | sed -n 's/.*"maximum": \([0-9]\+\).*/\1/p')
  min_id=$(sed -n "${line_minus_1}p" "$temp_info" | sed -n 's/.*"minimum": \([0-9]\+\).*/\1/p')

  # Print min_id and max_id
  echo "min_id: $min_id"
  echo "max_id: $max_id"

  # Check if min_id and max_id are defined
  if [[ -z "$min_id" || -z "$max_id" ]]; then
    echo "Error: min_id or max_id is not defined."
    exit 1
  fi

  # Loop over each tile and create a separate pipeline for each
  for ((i=0; i<num_tiles; i++)); do
    for ((j=0; j<num_tiles; j++)); do
      echo "$i $j"
      tile_x_min=$(python3 -c "print($x_min + $i * $tile_size_x)")
      tile_x_max=$(python3 -c "print($x_min + ($i + 1) * $tile_size_x)")
      tile_y_min=$(python3 -c "print($y_min + $j * $tile_size_y)")
      tile_y_max=$(python3 -c "print($y_min + ($j + 1) * $tile_size_y)")

      # Loop over each PointSourceId

      for ((id=$min_id; id<=$max_id; id++)); do
	echo $id
        output_file="${output_dir}/$(basename "$file" .laz)_tile_${i}_${j}_id_${id}.ply"

        # Start creating the PDAL pipeline for the current file
        temp_pipeline=$(mktemp)
        echo '{
          "pipeline": [' > "$temp_pipeline"

        # Add the current .laz file to the pipeline
        echo '    {
            "type": "readers.las",
            "filename": "'"$file"'"
          },' >> "$temp_pipeline"
	echo "1 0 0 -${min_x}  0 1 0 -${min_y}  0 0 1 0  0 0 0 1"
        cat >> "$temp_pipeline" <<EOF
        {
          "type": "filters.crop",
          "bounds": "([$tile_x_min, $tile_x_max], [$tile_y_min, $tile_y_max])"
        },
	{
            "type": "filters.transformation",
            "matrix": "1 0 0 -${min_x}  0 1 0 -${min_y}  0 0 1 0  0 0 0 1"
        },
        {
          "type": "filters.range",
          "limits": "PointSourceId[$id:$id]"
        },
        {
          "type": "writers.ply",
          "storage_mode":"little endian",
          "filename": "$output_file"
        }
      ]
    }
EOF
        # Execute the PDAL pipeline
        pdal pipeline "$temp_pipeline"
        rm "$temp_pipeline"
      done
    done
  done
done

echo "Tiling completed. Results saved to $output_dir"
exit 0
