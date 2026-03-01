people = {"Carter" : "+1-617-495-1000" , "David" : "+1-949-468-2750"}
name = input("Type Name ")
if name in people :
    number = people[name]
    print("Number:" , number)

else:
    print("Not Found")