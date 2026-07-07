import shutil
import os

src = r"C:\Users\Anush MH\.gemini\antigravity\brain\1e379f9c-f039-458c-bdad-f8af4fe05aca\shopping_bag_hero_1781516451032.png"
dst = r"assets\images\shopping_bag_hero.png"

try:
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print("Success: Copied shopping bag hero image.")
    else:
        print(f"Error: Source file does not exist: {src}")
except Exception as e:
    print(f"Exception: {e}")
