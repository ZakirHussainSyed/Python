import camelot

tables = camelot.read_pdf('sample-tables.pdf', pages="1")
print(tables)
tables.export('sample-tables.csv',f='csv',compress=True)
tables[1].to_csv('sample2.csv')

