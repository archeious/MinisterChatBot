require 'google_drive'

module Minister

  class Voting
    
    def initialize(sheet_id)
      @google_session = GoogleDrive::Session.from_config("config/config.json")
      @sheet = @google_session.spreadsheet_by_key(sheet_id)
    end # End initialize
    
    def processBitDonation(user, amount, message)
      #if amount < 100
      #  return
      #end

      votes = amount / 100.0
        
      votes_sheet = @sheet.worksheets[1]
      nextRow = 1
      if votes_sheet.rows.kind_of?(Array) 
        nextRow = votes_sheet.rows.length + 1
      end

      game_name =  ""
      if message.match(/.*#variety ([0-9]+)/)
        @sheet.worksheets[0].rows.each_with_index { |row,index|
          if row[0] == $~[1]     
            game_name = @sheet.worksheets[0].rows[index][1]        
          end
        }
      else
        return
      end
      
      game_index = nil
        
      puts "#{nextRow} update votes for #{message} by #{user} with #{amount} votes"
      votes_sheet[nextRow, 1] = Time.now.utc.iso8601
      votes_sheet[nextRow, 2] = user
      votes_sheet[nextRow, 3] = votes 
      if message 
        votes_sheet[nextRow, 4] = game_name
      end
      votes_sheet.save
    end # End processBitDonation
  
  end # End Class

end # End Module

