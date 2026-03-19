class Solution:
    def NextSmallerCircular(self, nums: list[int]) -> list[int]:
        n = len(nums)
        res = [-1] * n
        stack = [] # Still stores INDICES

        # Loop through the array twice (2 * n)
        for i in range(2 * n):
            # Use modulo to wrap around to the start
            curr_idx = i % n
            curr_val = nums[curr_idx]

            # Standard monotonic stack logic
            while stack and curr_val < nums[stack[-1]]:
                idx_to_update = stack.pop()
                res[idx_to_update] = curr_val
            
            # Only push indices during the first pass 
            # (or if you want to allow re-checking, but i < n is cleaner)
            if i < n:
                stack.append(curr_idx)
                
        return res

sol = Solution()
nums = [4, 2, 3, 6, 5]
print(sol.NextSmallerCircular(nums)) 
