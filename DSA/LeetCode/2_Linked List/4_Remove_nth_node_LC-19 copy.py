# Define List Node

class ListNode():
    def __init__(self, val=0, next=None ):
        self.val=val
        self.next = next

def build_linked_list(arg):
    dummy = ListNode(0)
    current = dummy
    for val in arg:
        current.next = ListNode(val)
        current = current.next
    return dummy.next

def print_linked_list(head):
    current=head
    while current:
        print(current.val, end="-->")
        current=current.next
    print("None")

class Solution():
    def removeNthFromEnd(self, head=[ListNode] , n = int) -> ListNode :
        dummy = ListNode(0,head)
        left = dummy
        right = head
        while n > 0 and right:
            right = right.next
            n -= 1
        
        while right:
            right = right.next
            left = left.next

        # Delete Node 
        left.next=left.next.next

        return dummy.next

sol = Solution()
head = build_linked_list([1,2,3,4,5])
new_head = sol.removeNthFromEnd(head, 2)
print_linked_list(new_head)




