scores = []
for i in range(3):
    score = int(input("Score: "))
    scores.append(score)    ######### also scores += [scores]

average = sum(scores)/len(scores)
print ("Average" , average)