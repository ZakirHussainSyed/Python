import sys 

names = ["Bill" , "Charlie" , "Fred" , "George" , "Ginny" , "Percy" , "Ron"]
name = input("Please type name ")


if name in name:
    print ("Found")             
    sys.exit(1)                

print("Not Found")
sys.exit(0)


