class Node:
    def __init__(self,data):
        self.data=data
        self.next=None

class Linked_list():
    def __init__(self):
        self.head=None
    def insert_in_begining(self,data):
        new_node=Node(data)
        new_node.next=self.head
        self.head=new_node

    def insert_at_end(self,data):
        new_node=Node(data)
        if self.head is None:
            self.head=new_node
            return
        current=self.head
        while current.next is not None:
                current=current.next
        current.next=new_node

    def insert_at_position(self, data, position):
        """Insert a node at a specific position (0-based index)"""
        new_node = Node(data)

        # Case 1: Insert at beginning
        if position == 0:
            new_node.next = self.head
            self.head = new_node
            return

        current = self.head
        index = 0

        # Traverse to (position - 1)
        while current is not None and index < position - 1:
            current = current.next
            index += 1

        # If position is out of range
        if current is None:
            print("Position out of range!")
            return

        # Insert new node
        new_node.next = current.next
        current.next = new_node
         
    def print_linked_list(self):
         current=self.head
         while current is not None:
              print (current.data,end="->")
              current=current.next
         print ("None")
ll=Linked_list()
ll.insert_in_begining(5)
ll.insert_in_begining(3)
ll.insert_in_begining(1)
ll.insert_at_end(7)
ll.insert_at_end(9)
ll.insert_at_end(10)
ll.insert_at_position(8,3)
ll.print_linked_list()

        
    
   