#! /usr/bin/ruby

# == Synopsis 
#   This program takes as input an HCD file and an ETD file.
#   It then filters the HCD file for the presence of ALL the ions provided
#   within a given tolerance (either an exact m/z or a ppm value).
#
# == Examples
#   Filter the file HCDFile.txt for the presence of 366.14  
#   with 0.1 m/z tolerance and output the corresponding ETD 
#   spectra from ETDfile.txt to the file ETDout.txt.
#     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14 --mzTol 0.1 --output ETDout.txt
#
#   Other examples:
#     Filter for the presence of both 366.14 AND 407.16 with 0.1 m/z tolerance.
#     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14,407.16 --mzTol 0.1 --output ETDout.txt
#
#     Filter for the presence of both 366.14 AND 407.16 with 200 ppm tolerance.
#     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14,407.16 --mzTol 0.1 --output ETDout.txt
#
# == Author
#   Jamie Sherman
#
# == Copyright
#   Copyright (c) 2011 UCSF. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php


require 'optparse'

class Scan
  attr_accessor :params, :data, :reporterIons
  
  def addPeak(xyarr)
    @data ||= []
    @data.push(xyarr.inject([]) {|arr, v| arr << v.to_f })
  end
  
  def has_ion(mz, tol)
    @data.each {|xy| return true if ( (xy[0] - mz).abs < tol ) }
    return false
  end
  
  def precursor
    params["PEPMASS"].split[0].to_f
  end
  
  def scanNumber
    params["TITLE"] =~ %r{Scan ([\d]+)}
    Regexp.last_match(1).to_i
  end
  
  def lge(a,b)
    return 1 if (a[1] > b[1])
    return -1 if (b[1] > a[1])
    return 0
  end
  
  def filter_by_abundance(keepnum)
    return if (keepnum > @data.size || keepnum == 0)
    dbyintensity = @data.sort{|a,b| b[1] <=> a[1] }
    dbyintensity = dbyintensity.slice(0..keepnum)
    @data = dbyintensity.sort {|a,b| a[0] <=> b[0] }
  end
  
  def rt
    params["TITLE"] =~ %r{\(rt=([\d|\.]+)\)}
    Regexp.last_match(1).to_f
  end
  
  def to_s
    s = "BEGIN IONS\nTITLE=#{params["TITLE"]}\nPEPMASS=#{params["PEPMASS"]}\nCHARGE=#{params["CHARGE"]}\n"
    @data.each {|d| s += d.join(" "); s+= "\n"}
    s += "END IONS\n\n"
    s
  end
  
end

class ScanPair
  attr_accessor :hcdScan, :etdScan, :keepMe
  def initialize
    @keepMe = false
    @hcdScan = Scan.new
    @etdScan = Scan.new
  end
end

class KatiKrunch
  def initialize(hcdFilename, etdFilename, keepnum)
    @index = {}
    @scanpairs = [] # the scans are kept in here in the scanpair container
    load_HCD_scans(hcdFilename, keepnum)
    @scanpairs.each_with_index {|sp,ind| @index[sp.hcdScan.scanNumber] = ind }
    load_ETD_scans(etdFilename)
    # delete if either of the scans data are nil (empty) or if for some reason the precursor is more than 10 m/z units different
    @scanpairs.delete_if{|sp| sp.hcdScan.data == nil || sp.etdScan.data == nil || (sp.hcdScan.precursor - sp.etdScan.precursor).abs > 10.0 }
  end
  
  def printScanMatches
    @scanpairs.each do |sp|
       if sp.etdScan.data == nil
         puts "******==> #{sp.hcdScan.scanNumber}" 
       else
         puts "#{sp.hcdScan.scanNumber} -> #{sp.etdScan.scanNumber}"
       end
     end
  end
  
  def load_HCD_scans(fname, keepnum)
    params = nil
    open(fname, "r").each do |line|
      if line =~ %r{BEGIN IONS}
        params = {}
        @scanpairs.push( ScanPair.new )
      end
      if line =~ %r{\w+=}
        val = line.split('=')
        params[val.shift] = val.join('=').chomp.chomp
      end
      @scanpairs[-1].hcdScan.addPeak(line.split) if line =~ %r{^\d[\s|\d|\.]+$}
      if line =~ %r{END IONS}
        @scanpairs[-1].hcdScan.params = params  
        @scanpairs[-1].hcdScan.filter_by_abundance(keepnum) 
      end
    end
  end
  
  def load_ETD_scans(fname)
    params = nil
    pair = nil
    open(fname, "r").each do |line|
      if line =~ %r{BEGIN IONS}
        params = {}
      end
      if line =~ %r{TITLE=Scan\s([\d]+) }
        etdScanNum = Regexp.last_match(1).to_i
        # the HCD scan should ALWAYS be 1 less than the ETD
        hcdScanNum = etdScanNum - 1
        pair = @scanpairs[@index[hcdScanNum]]
      end
      if line =~ %r{\w+=}
        val = line.split('=')
        params[val.shift] = val.join('=').chomp.chomp
      end
      pair.etdScan.addPeak(line.split) if line =~ %r{^\d[\s|\d|\.]+$}
      pair.etdScan.params = params  if line =~ %r{END IONS}
    end
  end
  
  def filter_for(mz, tol)
    @scanpairs.delete_if { |pair| !pair.hcdScan.has_ion(mz, tol) }
  end

  def print_hcd
    @scanpairs.each {|sp| puts sp.hcdScan.to_s }
  end
    
  def print_etd(fp)
    @scanpairs.each {|sp| fp.puts sp.etdScan.to_s }
  end
end


class App
  attr_reader :options

  def initialize(arguments)
    @arguments = arguments
    @options = {}
  end

  # Parse options, check arguments, then process the command
  def run
    if parsed_options? && arguments_valid?     
      process_arguments   
      process_command
    else
      output_usage
    end
  end
  
  protected
  
    def parsed_options?
      
      @opts = OptionParser.new do |opt|
        opt.banner =  %s{
 Synopsis 
   This program takes as input a pair of files, one 
   HCD file and one ETD file. The files are assumed 
   to correlate meaning the Percursor of HCD scan X 
   is the same precursor in ETD scan X+1. The correlated 
   scans are stored as a pair then the HCD scan is 
   filtered for the presence of ALL the desired ions, 
   if present the scan pair is kept if absent the scan 
   pair is removed. After filtering the remaining ETD 
   scans are written out to either STDOUT or the file 
   name provided.
  
 Usage:
 > katikruncher --option Value

   Options --hcd, --etd, --mz and either --mzTol or 
   --ppmTol are required

 Examples
   
   Filter the file HCD.txt for the presence of 366.14  
   with 0.1 m/z tolerance and output the corresponding ETD 
   spectra from ETD.txt to the file OUT.txt.
 
 > katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14 --mzTol 0.1 --out OUT.txt
  
   Other examples:
     Filter for the presence of both 366.14 AND 407.16 
     with 0.1 m/z tolerance.
   
 > katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14,407.16 --mzTol 0.1 --out OUT.txt
  
     Filter for the presence of both 366.14 AND 407.16 with 
     200 ppm tolerance.
   
 > katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14,407.16 --ppmTol 200 --out OUT.txt
  
 Author
   Jamie Sherman
  
 Flags:
  }
              
              
        opt.on("--hcd HCDFILENAME", "The HCD file to filter for the ", "perscibed m/z values.") do |fname|
          @options[:hcdFile] = fname
        end
              
        opt.on("--etd ETDFILENAME", "The corrolated ETD file.") do |fname|
          @options[:etdFile] = fname
        end
              
        @options[:mzArray] = []
        opt.on("--mz F1,F2,F3", Array, "The fragments to test for in the ", "HCD file (All must be present).") do |mzVals|
          @options[:mzArray] = mzVals
        end
              
        @options[:mzTolerance] = 0.0
        opt.on("--mzTol DELTAMZ", Float, "The tolerance to allow for the m/z ", "values from --mz above.") do |dMz|
          @options[:mzTolerance] = dMz
        end
          
        @options[:ppmTolerance] = 0.0      
        opt.on("--ppmTol [PPM]", Float, "The tolerance in Parts Per Million for ", "the m/z values entered.") do |ppm|
          @options[:ppmTolerance] = ppm
        end
        
        @options[:mostAbundant] = 0
        opt.on("--keepN NUM", Integer, "[optional] The fragment to match must be on ", "of the NUM most abundant.") do |num|
          @options[:mostAbundant] = num   
        end
        
        opt.on("--out FILENAME", "Write the scans to FILENAME. ", "Write to terminal otherwise.") do |fname|
          @options[:outFile] = fname
        end
              
        opt.on("-h", "--help", "This help page.") { puts @opts }
        
        opt.separator ""
      end
      @opts.parse!(@arguments) 
      #puts @options
      true
    end

    # True if required arguments were provided
    def arguments_valid?
      # check the parameters have values
      return false unless  @options.has_key?(:hcdFile)
      return false unless  @options.has_key?(:etdFile)      
      return false if      @options[:mzArray].empty?
      return false unless (@options[:mzTolerance] > 0.0 || @options[:ppmTolerance] > 0.0 )
      # check the file exists
      return false unless File.file?(@options[:hcdFile])
      return false unless File.file?(@options[:etdFile])
      true
    end
    
    
    def output_usage
      puts @opts
    end
    
    def process_arguments
      @options[:mzArray] = @options[:mzArray].inject([]) {|res,x| res << x.to_f}
    end
    
    def process_command
      usePPM = (@options[:ppmTolerance] > 1)
      kk = KatiKrunch.new(@options[:hcdFile], @options[:etdFile], @options[:mostAbundant])
      @options[:mzArray].each do |mz|
        dmz = (usePPM ? ((mz*@options[:ppmTolerance])/1000000.0) : @options[:mzTolerance] )
        kk.filter_for(mz, dmz)
      end
      fp = STDOUT 
      fp = File.open(@options[:outFile], 'w') if @options.has_key?(:outFile)
      kk.print_etd(fp)
    end

end

me = App.new(ARGV)
me.run



