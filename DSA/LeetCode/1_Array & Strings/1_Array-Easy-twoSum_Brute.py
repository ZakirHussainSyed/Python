from typing import List

class Solution:
    def twoSum(self, nums: List[int],target: int)->List[int]:
        for i in range(len(nums)):                  # ✅ no i=0 inside range()
            for j in range(i + 1, len(nums)):
                a = nums[i] + nums[j]
                if a==target:
                    return print([i,j])

sol=Solution()
nums= [1,2,3,4,5]
target=3
sol.twoSum(nums,target)                
