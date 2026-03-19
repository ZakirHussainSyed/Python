# Monotonic Stack

class Solution():
    def NextGreater(self , nums1:list[int]) ->list[int]:
        nums1idx = { n:i for i , n in enumerate(nums1) }
        res = [-1]*len(nums1)

        stack = []
        for i in nums1:
            while stack and i > stack[-1]:
                val = stack.pop()
                idx = nums1idx[val]
                res[idx] = i
            
            stack.append(i)
        return res
        
sol = Solution()
nums1 = [4,2,3,6,1]

print(sol.NextGreater(nums1))