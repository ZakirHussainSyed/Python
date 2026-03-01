import camelot
import pandas as pd
import matplotlib.pyplot as plt

## Extract Tables from pdf to CSV

tables = camelot.read_pdf("/Users/zakirhussainsyed/Downloads/stats.pdf","1",)
tables.export ("/Users/zakirhussainsyed/Downloads/stats.csv",f="csv",compress=True)

# Seperate RCS and SMS tables in CSV
tables[0].to_csv("/Users/zakirhussainsyed/Downloads/rcs_table.csv")
tables[1].to_csv("/Users/zakirhussainsyed/Downloads/sms_table.csv")

## Open CSV

rcs= pd.read_csv("/Users/zakirhussainsyed/Downloads/rcs_table.csv")
sms= pd.read_csv("/Users/zakirhussainsyed/Downloads/sms_table.csv")

# Chart 

x = rcs["Date"]
y = rcs["Success rate"]

plt.figure()
plt.plot(x, y)
plt.xlabel("Date")
plt.ylabel("Success rate")
plt.title("RCS Messaging Success rate")
plt.show()


