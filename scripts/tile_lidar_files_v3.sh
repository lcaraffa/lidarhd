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



# Create the output directory if it doesn't exist
mkdir -p "$output_dir"


# Loop over each .laz file
for file in "$input_dir"/*.laz; do
  x_min=$(pdal info --metadata $file | grep minx  | grep -oP '"minx":\s*\K\d+')
  x_max=$(pdal info --metadata $file | grep maxx  | grep -oP '"maxx":\s*\K\d+')
  y_min=$(pdal info --metadata $file | grep miny  | grep -oP '"miny":\s*\K\d+')
  y_max=$(pdal info --metadata $file | grep maxy  | grep -oP '"maxy":\s*\K\d+')
  # Calculate the number of tiles
  num_tiles=$((2 ** pow))
  tile_size_x=$(python3 -c "print(($x_max - $x_min) / $num_tiles)")
  
  output_file="${output_dir}/$(basename "$file" .laz)_#.laz"
  pdal tile -i "$file" -o "${output_file}" --length "$tile_size_x"  --origin_x ${x_min} --origin_y ${y_min}
  
done

for file in "${output_dir}"/*.laz; do
  echo $file
  temp_info=$(mktemp)
  pdal info --all --input $file > ${temp_info}
  nn=$(cat ${temp_info} | grep -n "PointSourceId" | awk -F: 'NR==3 {print $1}')

  # Calculer les numéros de ligne pour -1 et -2
  line_minus_1=$(($nn - 1))
  line_minus_2=$(($nn - 2))

  # Print line numbers
  max_id=$(sed -n "${line_minus_2}p" "$temp_info" | sed -n 's/.*"maximum": \([0-9]\+\).*/\1/p')
  min_id=$(sed -n "${line_minus_1}p" "$temp_info" | sed -n 's/.*"minimum": \([0-9]\+\).*/\1/p')

  # Check if min_id and max_id are defined
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

    # Add the current .laz file to the pipeline
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
        # Execute the PDAL pipeline
        pdal pipeline "$temp_pipeline"
        rm "$temp_pipeline"
  done
  rm $file
done


exit 0
