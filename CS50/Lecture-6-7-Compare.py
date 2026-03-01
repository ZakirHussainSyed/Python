s= input ("Do you agree? ")

s = s.lower()

if s in ["y" , "yes"]:
    print ("Agreed.")

elif s in ["n" , "no"]:
    print ("Not Agreed")

else :
    print ("Please enter y or yes to Agree and  n or no to Disagree")

