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

exit 0
