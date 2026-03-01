name = "Ava"
age = 28
is_active = True
price = 19.99


names = ["Ava", "Ben", "Cara"]
person = {"name": "Ava", "age": 28}

print("########################### Loops ###############################")

for n in names:
    print(n)

for k, v in person.items():
    print(k, v)

print("#####################  If Statement #####################")

if age >= 18:
    print("adult")
else:
    print("minor")