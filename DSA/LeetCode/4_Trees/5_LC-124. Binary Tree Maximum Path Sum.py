# Define TreeNode

class TreeNode:
    def __init__(self, val = 0, left = None, right = None):
        self.val = val
        self.left = left
        self.right = right

# Build TreeNode

def levelinserttree(arr, i, n):

    temp = TreeNode(arr[i])
    root = temp
    n = len(arr)
    if i > n or root is None:
        return None
    root.left = levelinserttree(arr, i*2+1, n)
    root.right = levelinserttree(arr, i*2+2 , n)

class Solution:
    def BinaryMaXPathSum(self, root:"TreeNode" ) -> int:
        res = []
        def dfs(root):
            if root is None:
                return 0

            leftMax = dfs(root.left)
            rightMax = dfs(root.right)
            leftMax = max(0,leftMax)
            rightMax = max(0,rightMax)

            return root.val + max(leftMax,rightMax)
        return root