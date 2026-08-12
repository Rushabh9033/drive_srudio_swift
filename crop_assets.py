import os
from PIL import Image

car_dir = 'assets/vehicles/stock'
for f in os.listdir(car_dir):
    if f.endswith('.png'):
        path = os.path.join(car_dir, f)
        img = Image.open(path)
        if len(img.split()) == 4:
            bbox = img.split()[3].getbbox()
            if bbox:
                img_cropped = img.crop(bbox)
                img_cropped.save(path)
                print(f"Cropped {f} from {img.size} to {img_cropped.size}")
        else:
            print(f"{f} has no alpha, skipping")
