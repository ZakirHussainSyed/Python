class Bank():
    def __init__(self,accountNumber,balance):
        self.accountNumber= accountNumber
        self.balance=balance

    def credit(self,amount):
        self.balance+=amount
        return print ("Account No : ",self.accountNumber," , Credited with ",amount,"and total balance is ",self.balance) 

    def debit(self,amount):
        self.balance-=amount
        return print ("Account No : ",self.accountNumber," , Debited with ",amount,"and total balance is ",self.balance)     

accNo=input("Please enter Account number: ")

a1= Bank(accNo,1000)

transaction = input("For Deposit type 'deposit' , For withdraw type 'withdraw': ")
if transaction == "deposit":
    amount= float(input("How much? type amount: "))
    a1.credit(amount)
elif transaction == "withdraw":
    amount= input("How much? type amount: ")
    a1.debit(amount)
else:
    print ("Please Enter valid Answer from Options")