import os
from PIL import Image

car_dir = 'assets/vehicles/stock'
for f in os.listdir(car_dir):
    if f.endswith('.png'):
        img = Image.open(os.path.join(car_dir, f))
        # get the bounding box of non-transparent pixels
        # split returns bands (R,G,B,A). alpha is [3]
        if len(img.split()) == 4:
            bbox = img.split()[3].getbbox()
            print(f"{f}: size={img.size}, true_bbox={bbox}")
        else:
            print(f"{f}: size={img.size}, no alpha")
