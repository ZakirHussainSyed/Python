from typing import List

class Solution:
    def TwoSum(self, nums:List , target:int) -> int:
        map = {}

        for i , n in enumerate(nums):
            diff = target - n
            if diff in map:
                return [map[diff],i]
            map[n] = i

sol = Solution()
nums = [1 , 2 , 4 , 5 , 6 , 7]
target = 9
print(sol.TwoSum(nums,target))