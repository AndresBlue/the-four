"""The key of the electrical panels: its maps, brought in.

    python tools/props/prepare_key_textures.py

Reads the download's 2048 maps in source_assets/props/key_chain/ (outside git;
the author's Sketchfab download, assets/props/key/key-chain.zip) and writes
to assets/props/hotel/key_chain/, at 512 (a key is a few centimetres across):
the colour, the normal map, and the occlusion, roughness and metal packed in
the red, green and blue of one image, as the other models are. The rough,
metal and occlusion maps come as 16-bit greys. Then, in Godot,
tools/props/bake_key.gd bakes the mesh. Needs numpy and Pillow.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
SOURCE = os.path.join(ROOT, 'source_assets', 'props', 'key_chain')
TARGET = os.path.join(ROOT, 'assets', 'props', 'hotel', 'key_chain')
SIZE = 512


def grey(name):
    image = Image.open(os.path.join(SOURCE, name + '.png'))
    values = np.asarray(image).astype(np.float32)
    if values.max() > 255.0:
        values = values / 65535.0 * 255.0
    if values.ndim == 3:
        values = values[:, :, 0]
    return Image.fromarray(values.round().astype(np.uint8), 'L').resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(TARGET, exist_ok=True)
    Image.open(os.path.join(SOURCE, 'KeyChainAlbedo.png')).convert('RGB').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(TARGET, 'key_chain_albedo.jpg'), quality=92)
    Image.open(os.path.join(SOURCE, 'KeyChainNormal.png')).convert('RGB').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(TARGET, 'key_chain_normal.png'))
    Image.merge('RGB', (grey('KeyChainAOC'), grey('KeyChainRough'), grey('KeyChainMetallic'))).save(os.path.join(TARGET, 'key_chain_orm.jpg'), quality=92)
    print('wrote', os.path.normpath(TARGET))


if __name__ == '__main__':
    main()
