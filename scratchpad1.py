# Defining a function to concatenate rows to DataFrames
def concat_row(row, df):
      # Converting the new row to a DataFrame
      row_df = pd.DataFrame([row])

      # Using 'concat' to append the new row
      df = pd.concat([df, row_df], ignore_index=True)

      return df

# Initializing the DataFrame of turns of debate with padding data
df_debates_turns = pd.DataFrame(columns=df_debates.columns)
padding_row = {
    'Title': 'title',
    'Debate': 'debate',
    'Date': '2024-07-18',
    'Participants': 'participants',
    'Moderators': 'moderators',
    'Speaker': 'speaker',
    'Text': 'text'
}

# Concatenating the row to the DataFrame of turns of debate
df_debates_turns = concat_row(padding_row, df_debates_turns)
df_debates_turns['Date'] = df_debates_turns['Date'].astype('datetime64[ns]') # Explicitly setting the column 'Date' to the right data type

# Initializing variables to track consecutive speakers and their texts
previous_speaker = None
previous_text = ''

# Iterating through rows of the DataFrame of debates
for index, row in df_debates.iterrows():
    # Capturing the columns into variables for streamlined handling
    title = row['Title']
    debate = row['Debate']
    date = row['Date']
    participants = row['Participants']
    moderators = row['Moderators']
    speaker = row['Speaker']
    text = row['Text']
    
    # Checking if the speaker remains the same
    if previous_speaker == speaker:
        previous_text += ' ' + text
    else:
        # Adding the row of the consolidated speaker
        if previous_speaker is not None:
            new_row = {
                'Title': previous_title,
                'Debate': previous_debate,
                'Date': previous_date,
                'Participants': previous_participants,
                'Moderators': previous_moderators,
                'Speaker': previous_speaker,
                'Text': previous_text
            }

            # Concatenating the row to the DataFrame of turns of debate
            df_debates_turns = concat_row(new_row, df_debates_turns)
        # Updating the next previous variables
        previous_title = title
        previous_debate = debate
        previous_date = date
        previous_participants = participants
        previous_moderators = moderators
        previous_speaker = speaker
        previous_text = text

# Adding the row of the last speaker
new_row = {
    'Title': previous_title,
    'Debate': previous_debate,
    'Date': previous_date,
    'Participants': previous_participants,
    'Moderators': previous_moderators,
    'Speaker': previous_speaker,
    'Text': previous_text
}

# Concatenating the row to the DataFrame of turns of debate
df_debates_turns = concat_row(new_row, df_debates_turns)

# Dropping the padding row in the DataFrame of turns of debate
df_debates_turns.drop(0, inplace=True)
df_debates_turns = df_debates_turns.reset_index(drop=True)