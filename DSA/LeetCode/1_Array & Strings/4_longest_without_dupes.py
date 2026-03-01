"""
LC3:Given a string s, find the length of the longest substring without duplicate characters.
"""

class Solution:
    def lengthOfLongestSubstring(self, s: str) -> int:
        last={}
        left=0
        best=0
        for right, i in enumerate(s):
            if i in last and last[i]>=left:
                left=last[i]+1
            last[i]=right
            best =max(best,right-left+1)
        return best
            

s="abcddefgh"
sol=Solution()
print(sol.lengthOfLongestSubstring(s))
