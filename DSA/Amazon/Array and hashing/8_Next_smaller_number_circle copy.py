
class Solution:
    def nextSmall(self, nums:list[int]) -> list[int]:
        n = len(nums)
        res = [-1]*n

        stack =[]
        for i in range(2*n):
            curr_idx = i%n
            curr_val = nums[curr_idx]

            while stack and curr_val < nums[stack[-1]]:
                idx_to_update = stack.pop()
                res[idx_to_update] = curr_val
            
            if i < n:
                stack.append(curr_idx)
        
        return res
    

nums = [1,2,6,4,5,4]
sol = Solution()
print(sol.nextSmall(nums))