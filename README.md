# lidarhd
## Build env
```console
	python3 -m venv build/lidarhd_env
	build/lidarhd_env/bin/pip3 install numpy  Cython laspy laszip 
	source build/lidarhd_env/bin/activate
```

## Run
	Compute the tiling on 1 full tile
```console
	./run.sh --list_files datas/liste_dalle_1.txt  --project_path /home/laurent/code/lidarhd/outputs_1/
```	
	Computing the tiling on 9 tile croped around the center_1.txt with a bbox side of 100m
```console	
    ./run.sh --list_files datas/liste_dalle_9.txt  --project_path /home/laurent/code/lidarhd/outputs/ --center datas/center_1.txt --bbox_size 100 --do_crop 
```



