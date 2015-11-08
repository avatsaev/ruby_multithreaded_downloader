#author: Vatsaev Aslan (@avatsaev)

require 'open-uri'
require 'json'

@download_workers = [] #list of threads
@file_list = [] #files to download {filename: unique_file_name, uri: http_url_with_file_extension}
@progress_data = [] #contains progress data of each file {tid: thread_id, progress: float_in_percents, filename: self explanatory}


###################################-DOWNLOAD WORKER-##########################################

def download_it(file_descriptor, opts = {})

  if file_descriptor.nil? or file_descriptor[:uri].nil? or file_descriptor[:filename].nil?

    return

  else

    download_s = 0

    open(file_descriptor[:filename], 'wb') do |file|

      file << open(file_descriptor[:uri],

        {

          content_length_proc: ->(t){ # this callback gives total size of the file
            download_s = t #total size of the file in bytes
          },

          progress_proc: ->(s){ #this callback is called everytime openuri downloads a new chunck of the file, gives the amount of bytes downloaded so far

            if(@download_workers.count == @file_list.count) #if all threads are initiated 

              progress = s*100.0/download_s #transform progress from bytes to percentage

              @progress_data[opts[:tid]][:progress] = progress

            end

          }
        }

      ).read
    end

  end

end


######################################-PROGRESS DISPLAY-#################################################

def show_progress

  @progress_data.each do |p|
     print "Thread-#{p[:tid].to_s}\t"+p[:filename] + ":\t\t\t\t" + p[:progress].round(6).to_s+"%\n" #display progress of each file
  end

  #get the cursor at the top of display
  @progress_data.each do |p|
    print "\e[A\r"
  end

  #flush everything displayed at the bottom of the cursor
  $stdout.flush

end

###########################################################################################################


json_raw = open("http://a1.phobos.apple.com/us/r1000/000/Features/atv/AutumnResources/videos/entries.json").read #get the json
json_data = JSON.parse(json_raw) #parse it

json_data.each do |d| #setup the file list using the data from json
  d["assets"].each do |a|

    file_descriptor = {
      filename: a["accessibilityLabel"].gsub(" ","")+"-"+a["timeOfDay"]+File.extname(a["url"]),
      uri: a["url"]
    }

    @file_list << file_descriptor
  end

end

p "there is #{@file_list.count} files to download"

#setup the threads
@file_list.count.times do |i|

  @download_workers << Thread.new do
    filename = @file_list[i][:filename]
    @progress_data << {tid: i, progress: 0.000000, filename: filename}
    download_it(@file_list[i], {tid: i})
  end

end


@download_display_worker = Thread.new do

  running = true #downloads are not finished

  while(running) #while downloads are not finished

    show_progress() #refresh the current progress

    @progress_data.each do |p| #for each progress, check if downloads are finished

      running = false # for optimisation reasons, initially we'll consider that all downloads are finished

      if(p[:progress].to_i < 100) # if we find that at least one download is in progress
        running = true # we take back what we said before
        break #and break the loop because there's no reason to check the rest of downloads
      end

    end

  end

end


@download_workers.map(&:join) #let the multi-threading begin
@download_display_worker.join() #show progress
