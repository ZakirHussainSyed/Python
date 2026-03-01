
def twosum(self,nums:list[int],target):
    for i in range(nums):
            complement = target - nums[i]

nums=[1,2,3,4,5]
target=3
twosum(nums,target)