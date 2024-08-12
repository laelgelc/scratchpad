#hint
#create dataframe
data_CI = .............
#Set up the Waffle chart figure

fig = plt.figure(FigureClass = ............,
                 rows = ........, columns =....., #pass the number of rows and columns for the waffle 
                 values = ........., #pass the data to be used for display
                 cmap_name = 'tab20', #color scheme
                 legend = {'labels':[.......],
                            'loc': ........., 'bbox_to_anchor':(....),'ncol': 2}
                 #notice the use of list comprehension for creating labels 
                 #from index and total of the dataset
                )

#Display the waffle chart
plt.show()