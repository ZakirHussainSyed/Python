def recurrsive_binary_search(list,target):
    midpoint = len(list)//2
    if list[midpoint] == target:
        return True
    else:
        if list[midpoint] < target:
            return(recurrsive_binary_search(list[midpoint+1:],target))
        else:
            return(recurrsive_binary_search(list[:midpoint],target))


numbers = [1,2,3,4,5,6,7,8,9,10]        
result = recurrsive_binary_search(numbers,2)
print(result)

result = recurrsive_binary_search(numbers,8)
print(result)