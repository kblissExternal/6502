from PIL import Image

z = 0
rgb_image = Image.open("logo.png")
image = rgb_image.convert('P', palette=Image.ADAPTIVE, colors=64)

pixels = image.load()

out_file = open("logo.bin", "wb")
for y in range(128):
  for x in range(128):
    try:
      out_file.write(pixels[x, y].to_bytes(1, 'little'))
    except IndexError:
      out_file.write(z.to_bytes(1, 'little'))
