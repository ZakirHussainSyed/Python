import argparse
import os
import camelot
import pandas as pd
import matplotlib.pyplot as plt

def main(pdf_path):
    if not os.path.exists(pdf_path):
        raise FileNotFoundError("PDF not found : ",pdf_path)

    ## Extract Tables from pdf to CSV

    tables = camelot.read_pdf(pdf_path,"1",)
    if len(tables) == 0:
        raise ValueError("No tables found in PDF")
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

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract table from PDF and plot first two columns"
    )
    parser.add_argument(
        "pdf",
        help="Path to the PDF file"
    )

    args = parser.parse_args()
    main(args.pdf)
