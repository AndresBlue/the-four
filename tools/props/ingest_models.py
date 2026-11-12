"""Furniture and props for the hotel (docs/REALISM.md, phase 4), step one.

Reads the glTF downloads in source_assets/props/<id>/ (outside git; Poly Haven
glTF with its textures and info.json) and writes, for each model, to
assets/props/hotel/<id>/:

    <image>.jpg (.png with alpha)
                         its textures, at most MAX_SIZE px (2048 for the big
                         pieces in KEEP_2K), with a .import beside each (VRAM
                         compressed, mipmaps; normal maps as normal maps)
    <material>.tres      one material per glTF material: ORMMaterial3D when
                         the model packs occlusion, roughness and metalness in
                         one image (Poly Haven's "arm"), else StandardMaterial3D

Step two, in Godot, bakes the meshes with these materials:
tools/props/build_catalogue.gd. The register (source, authors, licence) goes
to docs/ASSETS.md between the MODELS markers.

The offices (--set=office, docs/OFICINAS.md 12) read their downloads from
source_assets/oficinas/<group>/<slug>/ (each group's registro.json) and from
source_assets/props/<slug>/ (registro_polyhaven_modelos.json), and write to
assets/props/office/<slug>/. A model's glTF is looked for in _gltf/ (the copy
Blender writes), in the download itself, or in its zip unpacked into _zip/.
assets/props/office/sources.json gets each glTF folder, and the OFFICE_MODELS
block of docs/ASSETS.md the register. NC, ND and SA licences are left out, and
a licence that is not CC0 prints a CREDIT line for the game's credits.

    python tools/props/ingest_models.py
    python -E -P tools/props/ingest_models.py [--only=<id>]
    python -E -P tools/props/ingest_models.py --set=office [--only=<slug>]
"""
import json
import os
import re
import sys
import zipfile

from PIL import Image, ImageChops, ImageFilter, ImageStat

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "source_assets", "props")
TARGET = os.path.join(ROOT, "assets", "props", "hotel")
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")
## The offices' downloads (--set=office): each in
## source_assets/oficinas/<group>/<slug>/ with its group's registro.json, or in
## source_assets/props/<slug>/ by registro_polyhaven_modelos.json; out to
## assets/props/office/<slug>/.
OFFICE_ROOT = os.path.join(ROOT, "source_assets", "oficinas")
OFFICE_GROUPS = ["muebles_a", "muebles_b", "equipos", "carpinteria", "muebles_c", "objetos"]
OFFICE_TARGET = os.path.join(ROOT, "assets", "props", "office")
## Where each office model's glTF is (res://), for build_catalogue.gd --sources=.
OFFICE_SOURCES = os.path.join(OFFICE_TARGET, "sources.json")
## Licences a model never comes in with (docs/OFICINAS.md 12).
BANNED = re.compile(r"\b(NC|ND|SA)\b|NonCommercial|NoDerivatives|ShareAlike")
## The res:// folder materials and imports point to: the offices' with --set=office.
RES = "res://assets/props/hotel/"
## A model's source folder when it is not SOURCE/<id> (the offices').
FOLDERS = {}

MAX_SIZE = 1024
## Downloads the game does not use (they were taken out in the September 2026
## cleanup): not brought in, not registered. Chandelier_01 is still read from
## source_assets/ by the trailer (tools/trailer3d).
## (metal_office_desk came back in October 2026: the offices' desks.)
SKIP = {"Chandelier_01", "Ottoman_01", "hanging_picture_frame_02", "modern_arm_chair_01", "round_wooden_table_01", "small_wooden_table_01", "television_02"}
## Downloaded in October 2026 (tools/props/fetch_models.py) and not placed
## yet: the frame wants its own way of being hung, the ducts a run along a
## ceiling.
SKIP |= {"hanging_picture_frame_01", "modular_airduct_rectangular_01"}
## And two that will not be: their labels are in Korean, and the
## extinguisher's inspection card is dated 2019.
SKIP |= {"korean_fire_extinguisher_01", "korean_public_payphone_01"}
## The offices' Poly Haven downloads that went to source_assets/props/
## (source_assets/oficinas/registro_polyhaven_modelos.json): --set=office
## brings them in, never the hotel.
SKIP |= {"sofa_02", "potted_plant_01", "pachira_aquatica_01", "calathea_orbifolia_01", "anthurium_botany_01", "plastic_bottle_gallon", "mid_century_lounge_chair"}
SKIP |= {"metal_stool_01", "metal_stool_02", "standing_picture_frame_01", "standing_picture_frame_02", "steel_frame_shelves_02", "steel_frame_shelves_03", "side_table_01", "coffee_table_round_01", "industrial_wall_lamp", "industrial_caged_sconce", "vintage_microwave", "vintage_electric_kettle"}
## And the offices' small things from Poly Haven of November 2026, the same.
SKIP |= {"vintage_stapler", "plastic_thermos", "modified_thermos", "metal_toolbox", "dustpan", "wooden_ladder_02", "wooden_broom", "mousetrap", "magnifying_glass_01", "round_spectacles", "projector_screen", "Television_01", "boombox"}
## The offices' Poly Haven kits the hotel already bakes by id (its PARTS and
## YAW): --set=office leaves them out. Under their slugs they would be baked
## again with no PARTS to split them, so each would come out as one mesh.
OFFICE_HOTEL_KITS = {"duct_fans_circular_polyhaven", "fire_escape_ladder_polyhaven", "fluorescent_battens_polyhaven", "pipes_modular_polyhaven", "silla_apilable_school_chair_01"}
## Materials that glow, which their glTF does not say: colour and strength.
## A chandelier's bulbs are lit lamps (hotel_geometry.gd puts them out in a
## dark room and with the power).
EMISSION = {"Chandelier_02_bulb": ((1.0, 0.8, 0.52), 9.0), "mounted_fluorescent_lights_glass": ((0.92, 0.97, 1.0), 4.0)}
## Cloth shades painted on the same image as the brass they hang from: what
## is white on that image glows (a mask made here, <image>_glow.jpg), in this
## colour and at this strength.
GLOW_WHITE = {"Chandelier_02": ((1.0, 0.76, 0.46), 2.6)}
## Materials that take no highlight of the lamps (specular_mode disabled): a
## mirror's. The engine draws a lamp's highlight as a blot, wider the bigger
## and the nearer the lamp, and on a glass that is all reflection the blot of
## a chandelier is a sheet of white over the whole mirror, with the
## camcorder's smear above and below it. What a mirror shows of a lamp is the
## lamp, and that it has already: from its room's reflection probe and from
## what is on the screen (tools/dev/mirror_look.gd).
NO_HIGHLIGHT = {"ornate_mirror_01"}
## Models whose glass has to be made clear here (material_tres()).
CLEAR_GLASS = {"vintage_grandfather_clock_01"}
## What is painted over on an office download's images before they are
## brought in (docs/OFICINAS.md 12: no lettering in another language, no
## makers' marks): by model and image, rectangles in the image's own pixels
## (x0, y0, x1, y1), each filled with the colour round it, with the colour
## given after them (r, g, b), or with what lies an offset (dx, dy) away: wood
## keeps its grain.
PATCHES = {
    # The maker's emblem in the middle of the dial.
    ("rotary_phone_black_sketchfab", "aiStandardSurface3_baseColor.png"): [(770, 3525, 935, 3700)],
    # The maker's name on the side and the model's number under the screen;
    # the screen's own picture (a login in English) made a dark glass, off.
    ("crt_terminal_ibm3278_sketchfab", "ibm_3278_baseColor.png"): [(491, 111, 503, 134), (336, 216, 357, 237)],
    ("crt_terminal_ibm3278_sketchfab", "display_baseColor.png"): [(0, 0, 512, 512, (14, 16, 15))],
    # The plate in English at the back, the maker's name embossed on the
    # front and the words over the hot and the cold taps (their marks stay).
    ("water_cooler_bottle_tboiston", "lambert1_baseColor.png"): [(244, 2114, 496, 2236), (1812, 2270, 2036, 2354), (3358, 2444, 3386, 2460), (3592, 2450, 3618, 2466)],
    ("water_cooler_bottle_tboiston", "lambert1_normal.png"): [(244, 2114, 496, 2236), (1812, 2270, 2036, 2354)],
    ("water_cooler_bottle_tboiston", "lambert1_metallicRoughness.png"): [(244, 2114, 496, 2236), (1812, 2270, 2036, 2354)],
    # The office door's room plate and its blue fire-door disc, in colour and relief.
    ("puerta_oficina_sousinho", "T_meeting_room_door_baseColor.png"): [(610, 390, 1235, 585, (0, 300)), (1940, 1900, 2215, 2160, (0, -400))],
    ("puerta_oficina_sousinho", "T_meeting_room_door_normal.png"): [(610, 390, 1235, 585, (0, 300)), (1940, 1900, 2215, 2160, (0, -400))],
    # The plain door's toilets sign, fire exit sign and fire-door disc.
    ("puerta_lisa_sousinho", "T_exit_door_1001_baseColor.jpg"): [(2380, 850, 2925, 1200, (0, 700)), (2390, 1245, 2920, 1465, (0, 700)), (1840, 1080, 2130, 1370, (0, 700))],
    ("puerta_lisa_sousinho", "T_exit_door_1001_normal.png"): [(2380, 850, 2925, 1200, (0, 700)), (1840, 1080, 2130, 1370, (0, 700))],
    # Two jokes in English printed on the steel door's glass.
    ("puerta_metal_tboiston", "lambert1_baseColor.png"): [(958, 136, 1122, 176, (0, 60)), (1333, 139, 1485, 179, (0, 60))],
    # The stencilled lines on the locker's door.
    ("taquilla_zambur", "initialShadingGroup_baseColor.png"): [(80, 295, 335, 545), (470, 280, 750, 550)],
    # The vending machine's brand sign, its snacks' made-up brands (the slots
    # are left empty) and a sticker by the coin slot.
    ("expendedora_attheseedof", "VendingMachine_baseColor.png"): [(59, 772, 772, 950), (59, 507, 760, 744), (261, 1655, 424, 1834)],
    # A label with symbols under the chrome chair's seat.
    ("retro_oficina_yj", "17_-_Default.001_baseColor.png"): [(850, 330, 1115, 780)],
    # A comic's cover and a starry one in the books' atlas, as plain cloth.
    ("libros_frodoundead", "Book_baseColor.png"): [(1256, 1741, 1686, 2038, (92, 62, 44)), (795, 297, 1239, 601, (92, 62, 44))],
    # The printer's name plate and its panel's English labels.
    ("impresora_okidata_papaj", "material_baseColor.png"): [(1432, 1540, 1768, 1752), (100, 1480, 1400, 1740), (780, 1820, 840, 1900)],
    # The shipping label with its barcode on the dirty box.
    ("caja_carton_krolzuzanna", "box_A_2_baseColor.png"): [(1636, 1380, 1756, 1520)],
    # Poly Haven's small things: the stapler's maker, the flask's name, the
    # television's maker, warning sticker and tag, the cassette player's
    # stickers and the labels over its deck.
    ("vintage_stapler", "vintage_stapler_diff_1k.jpg"): [(0, 35, 262, 104)],
    ("plastic_thermos", "plastic_thermos_diff_1k.jpg"): [(780, 860, 1015, 1000)],
    ("Television_01", "Television_01_diff_1k.jpg"): [(379, 707, 481, 731), (500, 775, 532, 905), (645, 748, 758, 901), (850, 51, 881, 143)],
    # The extinguisher's instruction label and the small print beside it, as its red body.
    ("extintor_loic", "extincteur_baseColor.jpg"): [(390, 80, 990, 945), (40, 445, 400, 940)],
    # The microfiche reader's screen: a chart with figures, made a grey glass, off.
    ("microfichas_maxdragonn", "filmscreen_baseColor.png"): [(0, 0, 512, 512, (48, 52, 52))],
    ("boombox", "boombox_diff_1k.jpg"): [(553, 389, 680, 502), (747, 512, 840, 625), (727, 788, 819, 891), (10, 80, 410, 230)],
}
## Images multiplied by a colour as they are brought in: the archive box's
## white board turned to kraft.
## The cloth chair's roughness (green of its metal-roughness maps) raised: its
## cushions matt cloth, its arms and base satin plastic, not the gloss it came with.
TINT = {("cajas_archivo_cozmoth", "material_baseColor.png"): (0.8, 0.64, 0.44),
    # The wall rack: its wood lighter, and no metal in it (its map gave the wood a quarter of it).
    ("perchero_pared_ehnri", "Scene_-_Root_baseColor.png"): (1.9, 1.8, 1.7),
    ("perchero_pared_ehnri", "Scene_-_Root_metallicRoughness.png"): (1.0, 1.15, 0.0),
    ("silla_tela_projectkaizen", "chairobjfinal_chair_sitting_and_back_pillow_Metallic_png-chairobjfinal_chair_sitting_and_back_pillow_Roughness_png.png"): (1.0, 2.4, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_seat_back_Metallic-chairobjfinal_seat_back_Roughness.png"): (1.0, 2.5, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_seat_rest_Metallic-chairobjfinal_seat_rest_Roughness.png"): (1.0, 1.6, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_back_handle_Metallic_png-chairobjfinal_back_handle_Roughness_png.png"): (1.0, 2.6, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_hand_rest_Metallic_png-chairobjfinal_hand_rest_Roughness_png.png"): (1.0, 1.4, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_wheel_handle_Metallic-chairobjfinal_wheel_handle_Roughness.png"): (1.0, 4.5, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_pole_Metallic-chairobjfinal_pole_Roughness.png"): (1.0, 4.4, 1.0),
    ("silla_tela_projectkaizen", "chairobjfinal_pole2_Metallic-chairobjfinal_pole2_Roughness.png"): (1.0, 4.8, 1.0),
}
# Big pieces seen close up keep 2048 px.
KEEP_2K = {"escritorio_tanker_lenawachs", "retro_oficina_yj", "escritorio_madera_collings", "expendedora_attheseedof", "GothicBed_01", "Sofa_01", "sofa_03", "ArmChair_01", "wooden_bookshelf_worn", "GothicCommode_01", "ClassicConsole_01", "vintage_grandfather_clock_01", "puerta_oficina_sousinho", "puerta_lisa_sousinho", "puerta_metal_tboiston"}

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{res}{model}/{file}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""


def safe(name):
    return re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_") or "material"


def paint_over(image, patches):
    """Each rectangle of PATCHES filled with its colour or the one round it
    (the median of a ring a little wider), its edge softened."""
    result = image.convert("RGBA" if "A" in image.getbands() else "RGB")
    ring = max(2, round(image.width / 1024 * 5))
    for patch in patches:
        x0, y0, x1, y1 = patch[:4]
        outer = result.crop((x0 - ring, y0 - ring, x1 + ring, y1 + ring))
        if len(patch) > 4 and len(patch[4]) == 2:
            dx, dy = patch[4]
            fill = result.crop((x0 - ring + dx, y0 - ring + dy, x1 + ring + dx, y1 + ring + dy))
        elif len(patch) > 4:
            colour = tuple(patch[4]) + ((255,) if result.mode == "RGBA" else ())
        else:
            mask = Image.new("L", outer.size, 255)
            mask.paste(0, (ring, ring, outer.width - ring, outer.height - ring))
            colour = tuple(int(v) for v in ImageStat.Stat(outer, mask).median)
        # Solid over the whole rectangle (a small one too), softened in its ring.
        soft = Image.new("L", outer.size, 0)
        soft.paste(255, (ring // 2, ring // 2, outer.width - ring // 2, outer.height - ring // 2))
        soft = soft.filter(ImageFilter.GaussianBlur(ring * 0.2))
        if not (len(patch) > 4 and len(patch[4]) == 2): fill = Image.new(result.mode, outer.size, colour)
        result.paste(Image.composite(fill, outer, soft), (x0 - ring, y0 - ring))
    return result


def copy_image(model, source_folder, uri, normal, size):
    image = Image.open(os.path.join(source_folder, uri))
    patches = PATCHES.get((model, os.path.basename(uri)))
    if patches: image = paint_over(image, patches)
    tint = TINT.get((model, os.path.basename(uri)))
    if tint:
        bands = image.convert("RGBA").split()
        image = Image.merge("RGBA", [b.point(lambda v, k=k: round(v * k)) for b, k in zip(bands[:3], tint)] + [bands[3]])
    alpha = image.mode in ("RGBA", "LA", "P") and "A" in image.convert("RGBA").getbands()
    file = safe(os.path.splitext(os.path.basename(uri))[0]) + (".png" if alpha else ".jpg")
    path = os.path.join(TARGET, model, file)
    if image.width > size:
        image = image.resize((size, round(image.height * size / image.width)), Image.LANCZOS)
    if alpha:
        image.convert("RGBA").save(path, optimize=True)
    else:
        image.convert("RGB").save(path, quality=90)
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w", newline="\n") as f:
            f.write(IMPORT.format(res=RES, model=model, file=file, normal=1 if normal else 2))
    return file


def glow_mask(model, source_folder, uri, size):
    """What is white (pale and without colour) on an image, as a mask."""
    r, g, b = Image.open(os.path.join(source_folder, uri)).convert("RGB").split()
    lowest = ImageChops.darker(ImageChops.darker(r, g), b)
    highest = ImageChops.lighter(ImageChops.lighter(r, g), b)
    # Pale: every channel over 140. Without colour: the channels within 45.
    pale = lowest.point(lambda v: 255 if v > 140 else 0)
    grey = ImageChops.subtract(highest, lowest).point(lambda v: 255 if v < 45 else 0)
    mask = ImageChops.multiply(pale, grey)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5))
    if mask.width > size:
        mask = mask.resize((size, round(mask.height * size / mask.width)), Image.LANCZOS)
    file = safe(os.path.splitext(os.path.basename(uri))[0]) + "_glow.jpg"
    path = os.path.join(TARGET, model, file)
    mask.convert("RGB").save(path, quality=90)
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w", newline="\n") as f:
            f.write(IMPORT.format(res=RES, model=model, file=file, normal=2))
    return file


def rough_from_gloss(model, source_folder, uri, factor, size):
    """A roughness image from a specular-glossiness one: one minus its alpha."""
    gloss = Image.open(os.path.join(source_folder, uri)).convert("RGBA").getchannel("A").point(lambda v: round(v * factor))
    rough = ImageChops.invert(gloss)
    if rough.width > size:
        rough = rough.resize((size, round(rough.height * size / rough.width)), Image.LANCZOS)
    file = safe(os.path.splitext(os.path.basename(uri))[0]) + "_rough.jpg"
    path = os.path.join(TARGET, model, file)
    rough.convert("RGB").save(path, quality=90)
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w", newline="\n") as f:
            f.write(IMPORT.format(res=RES, model=model, file=file, normal=2))
    return file


def material_tres(model, gltf, material, textures):
    pbr = material.get("pbrMetallicRoughness", {})
    # A specular-glossiness material (KHR_materials_pbrSpecularGlossiness, older
    # Sketchfab exports) is read as metal-roughness: its diffuse as the albedo,
    # no metal, roughness one minus its glossiness (from the alpha of its
    # specular-glossiness image when it has one; its specular colour is dropped).
    gloss = material.get("extensions", {}).get("KHR_materials_pbrSpecularGlossiness")
    if gloss is not None and "pbrMetallicRoughness" in material: gloss = None
    if gloss is not None:
        pbr = {"baseColorFactor": gloss.get("diffuseFactor", [1, 1, 1, 1]), "metallicFactor": 0.0, "roughnessFactor": 1.0 if "specularGlossinessTexture" in gloss else 1.0 - gloss.get("glossinessFactor", 1.0)}
        if "diffuseTexture" in gloss: pbr["baseColorTexture"] = gloss["diffuseTexture"]

    def image_of(ref):
        return gltf["images"][gltf["textures"][ref["index"]]["source"]]["uri"] if ref else None

    albedo = image_of(pbr.get("baseColorTexture"))
    mr = image_of(pbr.get("metallicRoughnessTexture"))
    occlusion = image_of(material.get("occlusionTexture"))
    normal = image_of(material.get("normalTexture"))
    orm = mr is not None and (occlusion is None or occlusion == mr)
    resources = []
    lines = []

    def texture(uri, key, is_normal=False):
        file = textures.setdefault(uri, copy_image(model, folder_of(model), uri, is_normal, textures["__size"]))
        resources.append(file)
        lines.append(f'{key} = ExtResource("{len(resources)}")')

    colour = list(pbr.get("baseColorFactor", [1, 1, 1, 1]))
    glass = material.get("alphaMode") == "BLEND" and "glass" in material["name"].lower()
    if albedo: texture(albedo, "albedo_texture")
    # A pane whose glTF kept neither an alpha in its colour nor one in its
    # image (the transmission it had in Blender is not exported) comes out as
    # a black board over whatever is behind it: a clock's dial. A third, for
    # the models listed (the ones brought in before are left as they look).
    if glass and model in CLEAR_GLASS and colour[3] > 0.99: colour[3] = 0.3
    lines.insert(0, "albedo_color = Color(%g, %g, %g, %g)" % tuple(colour))
    if orm:
        texture(mr, "orm_texture")
    else:
        lines.append("metallic = %g" % pbr.get("metallicFactor", 1.0 if mr else 0.0))
        lines.append("roughness = %g" % pbr.get("roughnessFactor", 1.0))
        if mr:
            texture(mr, "metallic_texture")
            lines.append("metallic_texture_channel = 2")
            texture(mr, "roughness_texture")
            lines.append("roughness_texture_channel = 1")
        if occlusion:
            lines.append("ao_enabled = true")
            texture(occlusion, "ao_texture")
    if gloss is not None and "specularGlossinessTexture" in gloss:
        resources.append(rough_from_gloss(model, folder_of(model), image_of(gloss["specularGlossinessTexture"]), gloss.get("glossinessFactor", 1.0), textures["__size"]))
        lines.append(f'roughness_texture = ExtResource("{len(resources)}")')
        lines.append("roughness_texture_channel = 0")
    if normal:
        lines.append("normal_enabled = true")
        texture(normal, "normal_texture", True)
    mode = material.get("alphaMode", "OPAQUE")
    if mode == "MASK":
        lines.append("transparency = 2")
        lines.append("alpha_scissor_threshold = %g" % material.get("alphaCutoff", 0.5))
    elif mode == "BLEND" and "glass" in material["name"].lower():
        lines.append("transparency = 1")
    elif mode == "BLEND":
        # Cut-out cloth fringes and crate holes: scissored, so they stay in
        # the depth pass and cast shadows.
        lines.append("transparency = 2")
        lines.append("alpha_scissor_threshold = 0.5")
    if material.get("doubleSided"):
        lines.append("cull_mode = 2")
    if material["name"] in NO_HIGHLIGHT:
        lines.append("specular_mode = 2")
    if material["name"] in EMISSION:
        glow, strength = EMISSION[material["name"]]
        lines.append("emission_enabled = true")
        lines.append("emission = Color(%g, %g, %g, 1)" % glow)
        lines.append("emission_energy_multiplier = %g" % strength)
    if material["name"] in GLOW_WHITE and albedo:
        glow, strength = GLOW_WHITE[material["name"]]
        resources.append(glow_mask(model, folder_of(model), albedo, textures["__size"]))
        lines.append("emission_enabled = true")
        lines.append("emission = Color(%g, %g, %g, 1)" % glow)
        lines.append("emission_energy_multiplier = %g" % strength)
        # Times the mask, not added to it.
        lines.append("emission_operator = 1")
        lines.append(f'emission_texture = ExtResource("{len(resources)}")')
    kind = "ORMMaterial3D" if orm else "StandardMaterial3D"
    head = [f'[gd_resource type="{kind}" load_steps={len(resources) + 1} format=3]', ""]
    for k, file in enumerate(resources):
        head.append(f'[ext_resource type="Texture2D" path="{RES}{model}/{file}" id="{k + 1}"]')
    return "\n".join(head + ["", "[resource]", f'resource_name = "{material["name"]}"'] + lines) + "\n"


def folder_of(model):
    return FOLDERS.get(model) or os.path.join(SOURCE, model)


def ingest_materials(model):
    folder = folder_of(model)
    gltf_file = next(f for f in os.listdir(folder) if f.endswith(".gltf"))
    gltf = json.load(open(os.path.join(folder, gltf_file), encoding="utf-8"))
    os.makedirs(os.path.join(TARGET, model), exist_ok=True)
    textures = {"__size": 2048 if model in KEEP_2K else MAX_SIZE}
    names = []
    for material in gltf.get("materials", []):
        name = safe(material["name"])
        with open(os.path.join(TARGET, model, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(material_tres(model, gltf, material, textures))
        names.append(name)
    return names


def ingest(model):
    names = ingest_materials(model)
    info = json.load(open(os.path.join(folder_of(model), "info.json"), encoding="utf-8"))
    return info, names


def models_block(rows):
    lines = [
        "<!-- MODELS: generado por tools/props/ingest_models.py, no editar a mano -->",
        "## Mobiliario y objetos (fase 4 de REALISM.md)",
        "",
        "Poly Haven, CC0 (dominio público): no exigen atribución: constan aquí y no en los créditos del juego. Descargas originales en `source_assets/props/` (fuera de git); en `assets/props/hotel/<id>/` quedan las texturas (1024 px, 2048 en los muebles grandes) y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/hotel/<id>.res`.",
        "",
        "| Modelo | Autoría | Licencia |",
        "|---|---|---|",
    ]
    for model, info in rows:
        lines.append(f"| [{info['name']}](https://polyhaven.com/a/{model}) | {', '.join(info['authors'])} | CC0 1.0 |")
    lines.append("<!-- /MODELS -->")
    return "\n".join(lines)


def register(rows):
    block = models_block(rows)
    text = open(REGISTER, encoding="utf-8").read()
    if "<!-- MODELS" in text:
        text = re.sub(r"<!-- MODELS.*?<!-- /MODELS -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def write_block(name, block):
    text = open(REGISTER, encoding="utf-8").read()
    if f"<!-- {name}:" in text:
        text = re.sub(rf"<!-- {name}:.*?<!-- /{name} -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def office_entries():
    """Every office model the registers mark ok, by slug: (folder, entry)."""
    found = {}
    for group in OFFICE_GROUPS:
        for entry in json.load(open(os.path.join(OFFICE_ROOT, group, "registro.json"), encoding="utf-8")):
            if entry.get("status") == "ok": found[entry["slug"]] = (os.path.join(OFFICE_ROOT, group, entry["slug"]), entry)
    for entry in json.load(open(os.path.join(OFFICE_ROOT, "registro_polyhaven_modelos.json"), encoding="utf-8")):
        if entry.get("estado") == "ok": found[entry["slug"]] = (os.path.join(ROOT, entry["carpeta"]), entry)
    return found


def office_bakes(entries):
    """The slugs --set=office bakes: every ok entry but the hotel's kits."""
    return sorted(slug for slug in entries if slug not in OFFICE_HOTEL_KITS)


def gltf_folder(folder):
    """Where a download's glTF is: the copy Blender wrote (_gltf/,
    tools/props/decimate.py), the download itself, or its zip unpacked into
    _zip/ (Sketchfab); None without one."""
    def has_gltf(place):
        return os.path.isdir(place) and any(f.endswith(".gltf") for f in os.listdir(place))
    for place in (os.path.join(folder, "_gltf"), folder):
        if has_gltf(place): return place
    unpacked = os.path.join(folder, "_zip")
    if not os.path.isdir(unpacked) and os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith(".zip"): continue
            with zipfile.ZipFile(os.path.join(folder, name)) as archive:
                members = archive.namelist()
                if not any(m.endswith(".gltf") for m in members): continue
                # Nothing written outside _zip/.
                if any(m.startswith(("/", "\\")) or ":" in m or ".." in m.replace("\\", "/").split("/") for m in members): continue
                archive.extractall(unpacked)
            break
    for here, _, files in sorted(os.walk(unpacked)):
        if any(f.endswith(".gltf") for f in files): return here
    return None


def office_block(rows):
    lines = [
        "<!-- OFFICE_MODELS: generado por tools/props/ingest_models.py --set=office, no editar a mano -->",
        "## Mobiliario y equipos de las oficinas (piso 2)",
        "",
        "Descargas originales en `source_assets/oficinas/<grupo>/<slug>/` y `source_assets/props/<slug>/` (fuera de git), con su registro (`registro.json`, `registro_polyhaven_modelos.json`); en `assets/props/office/<slug>/` quedan las texturas y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/office/<slug>.res`. Las que no son CC0 piden su línea en los créditos del juego (`CREDITS` de `game/ui/hotel_ui.gd`).",
        "",
        "| Modelo | Id | Autoría | Fuente | Licencia |",
        "|---|---|---|---|---|",
    ]
    for slug, entry in rows:
        lines.append(f"| [{entry['item']}]({entry['url']}) | `{slug}` | {entry['author']} | {entry['source']} | {entry['licence']} |")
    lines.append("<!-- /OFFICE_MODELS -->")
    return "\n".join(lines)


def office_main(only):
    global TARGET, RES
    TARGET = OFFICE_TARGET
    RES = "res://assets/props/office/"
    entries = office_entries()
    sources = json.load(open(OFFICE_SOURCES, encoding="utf-8")) if os.path.exists(OFFICE_SOURCES) else {}
    # A kit an earlier run wrote under its slug must not stay in the list the bake reads.
    for slug in OFFICE_HOTEL_KITS: sources.pop(slug, None)
    if only and only not in entries: print("SKIP", only, "not ok in the registers")
    if only in OFFICE_HOTEL_KITS: print("SKIP", only, "baked for the hotel, in assets/props/hotel/")
    for slug in office_bakes(entries):
        if only and slug != only: continue
        folder, entry = entries[slug]
        licence = entry.get("licence", "")
        if BANNED.search(licence):
            print("SKIP", slug, "licence", licence)
            continue
        place = gltf_folder(folder)
        if place is None:
            print("SKIP", slug, "no glTF")
            continue
        FOLDERS[slug] = place
        print(slug, ingest_materials(slug))
        sources[slug] = "res://" + os.path.relpath(place, ROOT).replace("\\", "/")
        # Anything but plain CC0 ("CC-BY 4.0 (model); texture source CC0" too) asks for a credit.
        if not licence.strip().upper().startswith("CC0"): print("CREDIT", slug, licence, entry.get("attribution", ""))
    os.makedirs(OFFICE_TARGET, exist_ok=True)
    with open(OFFICE_SOURCES, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(dict(sorted(sources.items())), indent=1, ensure_ascii=False) + "\n")
    # A download that goes into another's pieces (a door's hinges: tools/props/fit_models.json) is registered as "incluido".
    included = [(entry["slug"], entry) for group in OFFICE_GROUPS for entry in json.load(open(os.path.join(OFFICE_ROOT, group, "registro.json"), encoding="utf-8")) if entry.get("status") == "incluido"]
    write_block("OFFICE_MODELS", office_block(sorted([(slug, entries[slug][1]) for slug in sources if slug in entries] + included, key=lambda row: row[0])))


def main():
    args = sys.argv[1:]
    only = next((a[len("--only="):] for a in args if a.startswith("--only=")), "")
    if "--set=office" in args:
        office_main(only)
        return
    rows = []
    for model in sorted(os.listdir(SOURCE)):
        if not os.path.isdir(os.path.join(SOURCE, model)) or model in SKIP: continue
        # A folder of pieces that are not a glTF (the key's: tools/props/bake_key.gd).
        if not any(f.endswith(".gltf") for f in os.listdir(os.path.join(SOURCE, model))): continue
        if only and model != only:
            # Still in the register: --only writes the whole MODELS block again.
            rows.append((model, json.load(open(os.path.join(folder_of(model), "info.json"), encoding="utf-8"))))
            continue
        info, names = ingest(model)
        rows.append((model, info))
        print(model, names)
    register(rows)


if __name__ == "__main__":
    main()
