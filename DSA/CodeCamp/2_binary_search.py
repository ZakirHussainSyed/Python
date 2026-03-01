def binary_search(list,target):
    first = 0
    last  = len(list)-1

    while first <=last:
        midpoint = (first + last)//2     ### //2 is floor divide . it rounds of 3.5 to 3 .
        if list[midpoint] == target :
            return midpoint
        elif midpoint < target :
            first = midpoint
        else:
            last = midpoint
    return

def verify(midpoint) :
    if midpoint is not None:
        print ("The Target is found in list at index" , midpoint)
    else:
        print ("The target is not found in list")

numbers = [1,2,3,4,5,6,7,8,9]
result = binary_search(numbers,5)
verify(result)


        

