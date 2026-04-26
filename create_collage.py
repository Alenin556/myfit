from PIL import Image
import os

# Путь к папке с изображениями
image_folder = "assets/images"
images_to_use = [
    "Salad Lovers.jpg",
    "загрузка (4).jpg",
    "Творог, банан и миндаль✨.jpg"
]

# Загружаем изображения
img1 = Image.open(os.path.join(image_folder, images_to_use[0]))
img2 = Image.open(os.path.join(image_folder, images_to_use[1]))
img3 = Image.open(os.path.join(image_folder, images_to_use[2]))

# Приводим все к одному размеру
target_height = 400
ratio1 = target_height / img1.height
ratio2 = target_height / img2.height
ratio3 = target_height / img3.height

img1 = img1.resize((int(img1.width * ratio1), target_height))
img2 = img2.resize((int(img2.width * ratio2), target_height))
img3 = img3.resize((int(img3.width * ratio3), target_height))

# Создаем коллаж (горизонтальное расположение)
total_width = img1.width + img2.width + img3.width
collage = Image.new('RGB', (total_width, target_height))

# Вставляем изображения
collage.paste(img1, (0, 0))
collage.paste(img2, (img1.width, 0))
collage.paste(img3, (img1.width + img2.width, 0))

# Сохраняем коллаж
output_path = os.path.join(image_folder, "collage.jpg")
collage.save(output_path, quality=95)
print(f"Коллаж создан: {output_path}")
