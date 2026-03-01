
from typing import Optional


class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    def reverseList(self, head: Optional[ListNode]) -> Optional[ListNode]:
        prev = None
        current = head
        while current:
            temp = current.next
            current.next=prev
            prev=current
            current=temp
        return prev
def print_linked_list(head):
    while head:
        print(head.val, end=" -> ")
        head = head.next
    print("None")
Sol = Solution()

head = ListNode(1, ListNode(2, ListNode(3)))

new_head = Sol.reverseList(head)

print_linked_list(new_head)
