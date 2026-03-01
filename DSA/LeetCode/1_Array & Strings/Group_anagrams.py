
from collections import defaultdict 

class Solution:
    def GroupAnagram(self, strs: list[str]) -> list[list[str]]:
        anagram_map = defaultdict(list)

        for word in strs:
            key = ''.join(sorted(word))
            anagram_map[key].append(word)

        return list(anagram_map.values())

Sol = Solution()
strs = ["eat","tea","tan","ate","nat","bat"]

print(Sol.GroupAnagram(strs))