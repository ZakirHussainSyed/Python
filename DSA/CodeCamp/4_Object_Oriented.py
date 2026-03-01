class Student_Score:
    def __init__(self,name,sub1_mark,sub2_mark,sub3_mark):
        self.name=name
        self.sub1_mark=sub1_mark
        self.sub2_mark=sub2_mark
        self.sub3_mark=sub3_mark

    def average(self):
        average_marks = (self.sub1_mark + self.sub2_mark + self.sub3_mark)/3
        return print(self.name,": Average Score : " , average_marks)

s1=Student_Score("karan",100,100,100)
s1.average()

"""
 Other Way to Write this code 

"""

class Student_Score:
    def __init__(self,name,marks):
        self.name=name
        self.marks=marks

    def average(self):
        sum=0
        for val in self.marks:
            sum+=val
        return print ("TONY Average Score:", sum/len(self.marks))

s1=Student_Score("Tony", [99,99,100])
s1.average()