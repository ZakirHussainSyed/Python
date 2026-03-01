import sys

if len(sys.argv) !=2:
    print ("Missing Command-line Argument")
    sys.exit(1)

print("Hello," , sys.argv[1])
sys.exit(0)       ##### type echo $? in terminal window , to see exit code 