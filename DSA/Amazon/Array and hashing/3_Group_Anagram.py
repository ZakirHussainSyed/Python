from typing import List
from collections import defaultdict

class Solution():
    def GroupAnagram(self, s=List[str]) -> List[List[str]]:
        Group_anagram = defaultdict(list)

        for arg in s:
            key = ''.join(sorted(arg))
            Group_anagram[key].append(arg)
        
        return list(Group_anagram.values())

s = ["act","pots","tops","cat","stop","hat"]
sol = Solution()
print(sol.GroupAnagram(s))
