from typing import Optional
class ListNode():
    def __init__(self,val=0,next=None):
        self.val=val
        self.next=next

def build_linked_list(arg):
    dummy=ListNode()
    current=dummy
    for val in arg:
        current.next=ListNode(val)
        current=current.next

    return dummy.next

def print_linked_list(head):
    current=head
    while current:
        print(current.val,end="->")
        current=current.next
    print("None")


class Solution():
    def MergeSortedList(self,l1:Optional[ListNode],l2:Optional[ListNode])-> Optional[ListNode]:

        dummy = ListNode()
        current = dummy 

        while l1 and l2:
            if l1.val < l2.val :
                current.next=l1
                l1=l1.next
            else:
                current.next=l2
                l2=l2.next

            current=current.next

        if l1:
            current.next=l1
        elif l2:
            current.next=l2

        return dummy.next

l1=build_linked_list([1,2,3,4])
l2=build_linked_list([1,2,4])

Sol=Solution()
merged_head=Sol.MergeSortedList(l1,l2)
print_linked_list(merged_head)