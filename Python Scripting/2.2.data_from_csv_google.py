import pandas as pd

df=pd.read_csv("https://docs.google.com/spreadsheets/d/1U_0BQ_elbcvP7J2Nj3wV3-bOsPQD-3kUMNfKHry-JEc/edit?gid=1957999720#gid=1957999720.csv")
df.rename(columns={"FTHG":"Home Goals"}, inplace=True)
df.rename(columns={"FTAG":"Away Goals"}, inplace=True)
print(df)

