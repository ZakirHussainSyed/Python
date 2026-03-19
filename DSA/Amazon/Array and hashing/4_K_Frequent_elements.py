from typing import List
class Solution:
    def kFrequent(self,nums:List[int], k:int) -> List[int]:
        # Initializing hashmap and Freq
        count = {}
        freq = [[] for i in range(len(nums)+1)]

        # Count element and put it hashmap
        for n in nums:
            count[n] = 1 + count.get(n,0)
        
        # Arrange , number of times of n= index value of freq
        for n , c in count.items():
            freq[c].append(n)
        
        # Pick top k items and put in res, start from last to get bigger number 
        res = []
        for i in range(len(freq)-1, 0 ,-1):
            for n in freq[i]:
                res.append(n)
                if len(res) ==k:
                    return res

sol = Solution()        
nums = [1,1,1,2,2,3]
k = 2

sol = Solution()
print(sol.kFrequent(nums,k))

