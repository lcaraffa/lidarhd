import os
import numpy as np
import argparse
import open3d as o3d  # Utilisation de open3d

class PointCloudProcessor:
    def __init__(self):
        pass

    def save_pointcloud_tensor(self, ply_file, tensor):
        """Sauvegarde un tensor sous forme binaire en remplaçant l'extension .ply par .bin."""
        # Remplacer l'extension .ply par .bin
        bin_file = ply_file.replace(".ply", ".bin")
        
        # Sauvegarder le tensor sous forme binaire
        tensor.astype(np.float32).tofile(bin_file)

    def ply_to_tensor(self, ply_file):
        """Convertit un fichier .ply en un tensor numpy de type float32."""
        # Charger le fichier PLY avec open3d
        pcd = o3d.io.read_point_cloud(ply_file)
        
        # Extraire les points (x, y, z)
        points = np.asarray(pcd.points)
        
        # Vérifier si des couleurs sont présentes et les ajouter comme intensité
        if len(np.asarray(pcd.colors)) > 0:
            colors = np.asarray(pcd.colors)
            # Ajouter les couleurs comme la dernière colonne (intensité)
            return np.hstack((points, colors))
        else:
            # Si pas de couleur, ajouter une colonne d'intensité nulle
            return np.hstack((points, np.zeros((points.shape[0], 3))))  # Intensité 0,0,0 pour chaque point

def process_directory(directory):
    processor = PointCloudProcessor()
    
    for filename in os.listdir(directory):
        if filename.endswith(".ply"):
            ply_file = os.path.join(directory, filename)
            print(f"Processing file: {ply_file}")
            
            # Convertir le fichier PLY en tensor
            tensor = processor.ply_to_tensor(ply_file)
            
            # Sauvegarder le tensor converti avec l'extension .bin
            processor.save_pointcloud_tensor(ply_file, tensor)

def main():
    # Parser les arguments
    parser = argparse.ArgumentParser(description="Convert PLY files to Velodyne binary format.")
    parser.add_argument("directory", type=str, help="Directory containing the PLY files to convert.")
    args = parser.parse_args()

    # Traitement du répertoire
    process_directory(args.directory)

if __name__ == "__main__":
    main()
