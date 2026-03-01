# Define TreeNode
class TreeNode:
    def __init__(self, val=0, left=None, right = None):
        self.val = val
        self.left = left
        self.right = right

# Build TreeNode
def levelinsertTree(arr ,i, n):

    if i >= n or arr[i] is None:
        return None
    temp = TreeNode(arr[i])
    root = temp
    n = len(arr)

    root.left = levelinsertTree(arr, i*2+1, n)
    root.right = levelinsertTree(arr, i*2+2, n)
    return root

# Solution

class Solution():
    def lcaOfBST(self, root:"TreeNode", p = "TreeNode" , q = "TreeNode") -> TreeNode:
        curr = root
        while curr:
            if p.val < curr.val and q.val < curr.val:
                curr = curr.left
            elif p.val > curr.val and q.val > curr.val:
                curr = curr.right
            else:
                return curr


Sol = Solution()
arr = [4,2,6,1,3,5,7]

n = len(arr)
root = levelinsertTree(arr,0,n)
p = root.right.left   # Node with value 5
q = root.right        # Node with value 6
answer = Sol.lcaOfBST(root,p,q)
print(answer.val)


