def linear_search(list,target):

# This program tell you if target is there in list or not 

    for i in range(0,len(list)):
        if list[i] == target:
            return i
    return None

def verify(i):
    if i is not None:
        print("Target is found in list at index" , i)
    else:
        print("Target is not found in the list")

numbers = [1,2,3,4,5,6,7]

result = linear_search(numbers,5)
verify(result)
