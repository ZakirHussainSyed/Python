
class Solution():
    def validAnagram(self, s:str , t:str ) -> bool:
        if sorted(s) == sorted(t):
            return True
        else:
            return False

sol = Solution()
s = "abcde"
t= "edbca"
print(sol.validAnagram(s,t))
