from typing import Optional

class TreeNode:
    def __init__(self,val=0,left=None,right=None):
        self.val=val
        self.left = left
        self.right = right


class Solution:
    def preorderTraversal(self,root:Optional[TreeNode]) -> list[int]:
        result = []
        def preorder(root):
            if not root:
                return
            result.append(root.val)
            preorder(root.left)
            preorder(root.right)

        preorder(root)
        return result
    
def levelOrderInsert(arr,i,n):
    if i >= n or arr[i] is None:
        return None
    temp = TreeNode(arr[i])
    root = temp
    root.left = levelOrderInsert(arr, i*2+1, n)
    root.right = levelOrderInsert(arr , i*2+2 , n)

    return root

# Build Tree 

arr = [1,2,3,4,5,None,8,None,None,6,7,9]
n = len(arr)
root = levelOrderInsert(arr, 0, n)

# Solution 
Sol = Solution()
inoder_traversal = Sol.preorderTraversal(root)
print("Preorder Traversal :", inoder_traversal)


            