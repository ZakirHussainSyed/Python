# Monotonic Stack

class Solution():
    def NextSmaller(self, nums1: list[int]) -> list[int]:
        res = [-1] * len(nums1)
        stack = [] # We will store INDICES here

        for i in range(len(nums1)):
            # While stack is not empty and the current number 
            # is SMALLER than the number at the index on the top of the stack
            while stack and nums1[i] < nums1[stack[-1]]:
                # We found a 'Next Smaller' for the element at stack[-1]
                idx_to_fill = stack.pop()
                res[idx_to_fill] = nums1[i]
            
            # Push the current INDEX onto the stack
            stack.append(i)
            
        return res

sol = Solution()
nums1 = [4, 2, 3, 6, 4]
print(sol.NextSmaller(nums1)) 
# Output: [2, -1, -1, 4, -1]