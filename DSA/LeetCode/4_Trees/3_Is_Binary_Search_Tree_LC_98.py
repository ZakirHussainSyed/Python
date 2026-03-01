from typing import Optional

class TreeNode:
    def __init__(self,val=0,left=None,right=None):
        self.val=val
        self.left = left
        self.right = right

def levelOrderInsert(arr,i,n):
    if i >= n or arr[i] is None:
        return None
    temp = TreeNode(arr[i])
    root = temp
    root.left = levelOrderInsert(arr, i*2+1, n)
    root.right = levelOrderInsert(arr , i*2+2 , n)

    return root


class Solution:
    def inorderTraversal(self,root:Optional[TreeNode]) -> bool:
        result = []
        def inorder(root):
            if not root:
                return
            inorder(root.left)
            result.append(root.val)
            inorder(root.right)

        inorder(root)
        print("Inorder Traversal :",result)
        for i in range(len(result)-1):
            if result[i] >= result[i+1]:
                return False
            i+=1
        return True

# Build Tree 
arr = [4,2,6,1,3,5,7]
#arr = [1,2,3,4,5,None,8,None,None,6,7,9]
n = len(arr)
root = levelOrderInsert(arr, 0, n)

# Solution 
Sol = Solution()
inoder_traversal = Sol.inorderTraversal(root)

print("Is Valid Binary Search Tree :", inoder_traversal)


            