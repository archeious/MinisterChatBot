require 'google_drive'

module Minister

  class Voting
    
    def initialize(sheet_id, settings)
      @google_session = GoogleDrive::Session.from_config("config/config.json")
      @sheet          = @google_session.spreadsheet_by_key(sheet_id)
      @vote_settings  = settings['operation']['voting']

    end # End initialize
    
    def recordVotes(sheet,row_number, time, user, votes, game_name)
      # Record votes to vote audit sheet
      sheet[row_number, @vote_settings['votes-sheet']['time-column'].to_i + 1]  = time
      sheet[row_number, @vote_settings['votes-sheet']['user-column'].to_i + 1]  = user
      sheet[row_number, @vote_settings['votes-sheet']['votes-column'].to_i + 1] = votes 
      sheet[row_number, @vote_settings['votes-sheet']['game-column'].to_i + 1]  = game_name
      sheet.save
    end

    def processBitDonation(user, amount, message)
      
      #verify the bit donation should trigger this operation
      game_name =  ""
      if message.match(/.*#{@vote_settings['trigger']} ([0-9]+)/)
        game_sheet = @sheet.worksheets[@vote_settings['games-sheet']['worksheet-number'].to_i]
        game_sheet.rows.each_with_index { |row,index|
          if row[@vote_settings['games-sheet']['id-column'].to_i] == $~[1]     
            game_name = game_sheet.rows[index][@vote_settings['games-sheet']['name-column'].to_i]
            break
          end
        }
      else
        return
      end
 
      # Process vote parameters
      if amount < @vote_settings['minimum_bits']
        return
      end
      votes = amount / @vote_settings['vote-divisor'].to_f
        
      # Find the next row in the votes sheets
      votes_sheet = @sheet.worksheets[@vote_settings['votes-sheet']['worksheet-number'].to_i]
      nextRow = 1
      if votes_sheet.rows.kind_of?(Array) 
        nextRow = votes_sheet.rows.length + 1
      end
        
      # Actually record the votes
      recordVotes(votes_sheet, nextRow, Time.now.utc.iso8601, user, votes, game_name)

    end # End processBitDonation
  
  end # End Class

end # End Module

