import pandas as pd

df=pd.read_csv("https://datahub.io/core/english-premier-league/_r/-/season-2425.csv")
df.rename(columns={"FTHG":"Home Goals"}, inplace=True)
df.rename(columns={"FTAG":"Away Goals"}, inplace=True)
print(df)



