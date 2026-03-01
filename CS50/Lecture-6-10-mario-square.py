def main():
    height = get_height()
    width  = get_width() 

    for i in range(height):
        for j in range(width):
            print ("#", end="")
        print()



def get_height():
    m = int(input("Height: " ))
    try :
        if m >0 :
            return m
    except ValueError:
        print ("This is not integer.")


def get_width():
    n = int(input("Height: " ))
    try :
        if n >0 :
            return n
    except ValueError:
        print ("This is not integer.")

main()


