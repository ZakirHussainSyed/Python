from typing import Optional
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

def build_linked_list(arg):
    head = ListNode(arg[0])
    current = head
    for val in arg[1:]:
        current.next=ListNode(val)
        current = current.next
    return head

class Solution:
    def ReverseLinkedList(self, head: Optional[ListNode]) -> Optional[ListNode]:
        prev = None
        current = head
        while current:
            temp = current.next
            current.next = prev
            prev = current
            current = temp
        
        return prev
    
def print_Linked_List(head):
    current = head
    while current:
        print(current.val , end="-->")
        current=current.next
    print("None")

arg = [1,2,3,4,5,6]
head = build_linked_list(arg)
sol=Solution()
new_head = sol.ReverseLinkedList(head)
print_Linked_List(new_head)


