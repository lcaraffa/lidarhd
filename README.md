# lidarhd
Quick and dirty stuff to tile LiDARHD data

## Build env
```console
	python3 -m venv build/lidarhd_env
	build/lidarhd_env/bin/pip3 install numpy  Cython laspy laszip 
	cd ./cgal && docker compose build
	source build/lidarhd_env/bin/activate
```

## Run
	process one lidarHD tile
```console
./run.sh --list_files datas/liste_dalle_1.txt  --project_path ${PWD}/outputs_1/
```	



