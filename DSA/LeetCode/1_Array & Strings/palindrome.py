s = "Was it a car or a cat I saw?"
forward = "".join(char.lower() for char in s if char.isalnum())
print(forward)