# Monotonic Stack

class Solution():
    def NextGreater(self , nums1:list[int] , nums2:list[int]) ->list[int]:
        nums1idx = { n:i for i , n in enumerate(nums1) }
        res = [-1]*len(nums1)

        stack = []
        for i in nums2:
            while stack and i > stack[-1]:
                val = stack.pop()
                idx = nums1idx[val]
                res[idx] = i
            
            if i in nums1:
                stack.append(i)
        return res
        
sol = Solution()
nums1 = [4,2,3,6]
nums2 = [4,2,3,6,1]

print(sol.NextGreater(nums1,nums2))