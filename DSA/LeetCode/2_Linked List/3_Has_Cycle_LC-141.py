from typing import Optional

### Define ListNode 

class ListNode():
    def __init__(self,val=0,next=None):
        self.val=val
        self.next=next


def build_linked_list(arg):
    dummy = ListNode(0)
    current= dummy
    for val in arg:
        current.next = ListNode(val)
        current = current.next

    return dummy.next

def print_Linked_List(head):
    current=head
    while current:
        print(current.val,end="-->")
        current=current.next
    print("None")

class Solution():
    def hascycle(self,head:ListNode) -> bool:
        slow , fast = head , head
        while fast and fast.next:
            slow=slow.next
            fast=fast.next.next
            if fast==slow:
                return True
        return False


head=build_linked_list([1,2,3,4,5])
print_Linked_List(head)
sol=Solution()

print(sol.hascycle(head))