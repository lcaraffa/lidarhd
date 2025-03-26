#!/bin/bash

# Default power of 2 for tiling
pow=2
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
  pdal info --all  --input $file > ${temp_info}
  nn=$(cat ${temp_info}  | grep -n  "PointSourceId" | awk -F: 'NR==2 {print $1}')
  echo "nn =>  $nn"
  # Calculer les numéros de ligne pour -1 et -2
  line_minus_1=$(($nn - 1))
  line_minus_2=$(($nn - 2))
  min_id=$(sed -n "${line_minus_2}p" "$temp_info" | sed -n 's/.*"maximum": \([0-9]\+\).*/\1/p')
  max_id=$(sed -n "${line_minus_1}p" "$temp_info" | sed -n 's/.*"minimum": \([0-9]\+\).*/\1/p')
  echo "$min_id $max_id"
  
  # Loop over each tile and create a separate pipeline for each
  for ((i=0; i<num_tiles; i++)); do
    for ((j=0; j<num_tiles; j++)); do
      tile_x_min=$(python3 -c "print($x_min + $i * $tile_size_x)")
      tile_x_max=$(python3 -c "print($x_min + ($i + 1) * $tile_size_x)")
      tile_y_min=$(python3 -c "print($y_min + $j * $tile_size_y)")
      tile_y_max=$(python3 -c "print($y_min + ($j + 1) * $tile_size_y)")
      output_file="${output_dir}/$(basename "$file" .laz)_tile_${i}_${j}.laz"

        # Start creating the PDAL pipeline for the current file
  echo '{
    "pipeline": [' > "$temp_pipeline"

  # Add the current .laz file to the pipeline
  echo '    {
      "type": "readers.las",
      "filename": "'"$file"'"
    },' >> "$temp_pipeline"
      
      cat >> "$temp_pipeline" <<EOF
    {
      "type": "filters.crop",
      "bounds": "([$tile_x_min, $tile_x_max], [$tile_y_min, $tile_y_max])"
    },
    {
      "type": "writers.las",
      "filename": "$output_file",
      "compression": "laszip"
    }
  ]
}
EOF

      

      cat $temp_pipeline
      echo " ------------ "

      # Run the PDAL pipeline for the current tile
      pdal pipeline "$temp_pipeline"

      # Remove the last writer stage to prepare for the next tile
      sed -i '$ d' "$temp_pipeline"
      sed -i '$ d' "$temp_pipeline"
    done
  done
  break
  # Remove the temporary pipeline file
  rm "$temp_pipeline"
done

echo "Tiling completed. Results saved to $output_dir"
exit 0
