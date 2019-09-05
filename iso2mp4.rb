#!/usr/bin/ruby

require 'pp'
require 'time'

def get_vinfo(infile)
  cmd = "HandBrakeCLI -i #{infile} -t 0 2>&1"
  puts "getting video information"
  res=`#{cmd}`

  #parse results
  
  titles = []
  t = nil
  mode = nil

  res.each do |x|
    if(x =~ /\+ title (\d+)/)
      titles << t if t
      t = {}
      mode = nil
      t[:number] = $1
      next
    end

    if(x =~ / +\+ duration: (\d\d:\d\d:\d\d)/)
      t[:duration] = $1
      next
    end

    if(x =~ / +\+ audio tracks:/)
      mode = :audio
      next
    end

    if(x =~ / +\+ subtitle tracks:/)
      mode = :subtitle
      next
    end

    # audio / subtitle
    if(x =~ / +\+ (\d+), (\w+)/)
      if(mode == :audio)
        t[:audio] ||= []
        t[:audio] << { :num => $1, :value => $2 }
      elsif(mode == :subtitle)
        t[:subtitle] ||= []
        t[:subtitle] << { :num => $1, :value => $2 }
      end
    end

  end # end of main loop

  titles << t if t
  titles
end


#pick titile based on conditions
def pick_titles(titles)

  min_duration = "00:20:00"
  t_list = []

  titles.each do |t|
    t_list << t if Time.parse(t[:duration]) > Time.parse(min_duration)
  end

  t_list
end



def gen_args(title)


  optstr = "-t #{title[:number]}"


  # audio 
  j_audio = (title[:audio]).inject([]){ |a,x| a << x if x[:value] =~ /japan/i ; a}
  f_audio = title[:audio] - j_audio
  if(f_audio.size > 0)
    optstr += " " + "-a #{f_audio[0][:num]}"
    if(j_audio.size > 0)
      optstr += ",#{j_audio[0][:num]}"
    end
  end

  # subtitle 
  if(title[:subtitle])
    j_subtitle = (title[:subtitle]).inject([]){ |a,x| a << x if x[:value] =~ /japan/i ; a}
    f_subtitle = title[:subtitle] - j_subtitle
    if(f_audio.size > 0)
      optstr += " " + "-s #{j_subtitle[0][:num]}"
    end
  end

  optstr
end



ARGV.each do |infile|
  unless infile =~ /\.ISO$/
    puts "extention must be .ISO"
    exit
  end

  infile =~ /(.*)\.ISO$/
  basename = $1
  outfile = $1 + ".mp4"


  puts "#{infile}, #{outfile}"

  titles = get_vinfo(infile)
  if(titles.size == 0)
    puts "no title found!"
    exit
  end

  picked = pick_titles(titles)

  picked.each do |p|
    outfile = picked.size > 1 ? basename + "_#{p[:number]}.mp4" : basename + ".mp4"
    #if exist, skip
    if Dir.glob(outfile).size > 0
      puts "Skip \"#{outfile}\" ..."
      next
    end

    args = gen_args(p)
    pp infile, outfile, args

    cmd = "HandBrakeCLI  -i #{infile} -t 1 -o #{outfile} -e x264 -E faac -w 480 -b 960 -I -x \"level=30:cabac=0:ref=1:analyse=all:me=umh:subme=6:no-fast-pskip=1:trellis=1\" -B 128 -R 48 -D 1 #{args} -v"
    pp cmd
    system cmd
  end
end
